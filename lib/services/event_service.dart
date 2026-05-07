import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import '../models/isar_event.dart';
import '../services/connectivity_service.dart';
import '../services/local_database_service.dart';
import 'notification_service.dart';
import 'supabase_client.dart';

class EventService {
  final LocalDatabaseService _db;
  final ConnectivityService _connectivity;

  EventService(this._db, this._connectivity);

  Stream<List<Event>> getEvents() {
    final controller = StreamController<List<Event>>.broadcast();

    Future<void> _run() async {
      // Always emit cached data first (works offline)
      try {
        final cached = await _db.getCachedEvents();
        if (!controller.isClosed) {
          controller.add(cached.map((e) => e.toEvent()).toList());
        }
      } catch (_) {}

      if (!_connectivity.isOnline) return;

      try {
        final rows = await supabase
            .from('events')
            .select()
            .order('date', ascending: true)
            .timeout(const Duration(seconds: 10));

        final list = (rows as List).map((r) => Event.fromMap(r)).toList();
        final isarEvents = list.map((e) => IsarEvent.fromEvent(e)).toList();
        await _db.cacheEvents(isarEvents);
        if (!controller.isClosed) controller.add(list);

        supabase
            .channel('events_changes')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'events',
              callback: (_) async {
                try {
                  final updated = await supabase
                      .from('events')
                      .select()
                      .order('date', ascending: true)
                      .timeout(const Duration(seconds: 10));

                  final updatedList =
                      (updated as List).map((r) => Event.fromMap(r)).toList();
                  final isarUpdated =
                      updatedList.map((e) => IsarEvent.fromEvent(e)).toList();
                  await _db.cacheEvents(isarUpdated);
                  if (!controller.isClosed) controller.add(updatedList);
                } catch (_) {}
              },
            )
            .subscribe();
      } catch (e) {
        print('Error fetching events: $e');
      }
    }

    _run();
    return controller.stream;
  }

  /// Create an event.
  ///
  /// **Online**: writes directly to Supabase.
  /// **Offline**: queues the action and inserts an optimistic local record so
  /// the event appears in the UI immediately.
  Future<void> createEvent({
    required String title,
    required String description,
    required String category,
    required String location,
    required DateTime date,
    required String time,
    required String organizer,
    required String organizerId,
  }) async {
    if (title.trim().isEmpty) throw Exception('Title required');

    const colors = ['1A56DB', '0E9F6E', 'E3A008', 'E02424', '9061F9', '3F83F8'];
    final color = colors[DateTime.now().millisecond % colors.length];

    if (_connectivity.isOffline) {
      // ── Queue for later sync ─────────────────────────────────────────────
      await _db.enqueuePendingAction(
        actionType: 'create_event',
        payloadJson: jsonEncode({
          'title':        title.trim(),
          'description':  description.trim(),
          'category':     category,
          'location':     location.trim(),
          'date':         date.toIso8601String(),
          'time':         time.trim(),
          'organizer':    organizer,
          'organizer_id': organizerId,
          'image_color':  color,
        }),
      );

      // Show the event locally right away (optimistic)
      final optimistic = IsarEvent(
        remoteId:    'pending_${DateTime.now().millisecondsSinceEpoch}',
        title:       title.trim(),
        description: description.trim(),
        category:    category,
        location:    location.trim(),
        date:        date,
        time:        time.trim(),
        organizer:   organizer,
        organizerId: organizerId,
        imageColor:  color,
        createdAt:   DateTime.now(),
        cachedAt:    DateTime.now(),
      );
      await _db.cacheEvents([optimistic]);
      return;
    }

    // ── Online path ──────────────────────────────────────────────────────────
    await supabase.from('events').insert({
      'title':        title.trim(),
      'description':  description.trim(),
      'category':     category,
      'location':     location.trim(),
      'date':         date.toIso8601String(),
      'time':         time.trim(),
      'attendees':    0,
      'organizer':    organizer,
      'organizer_id': organizerId,
      'image_color':  color,
    }).timeout(const Duration(seconds: 10));

    NotificationService.send(
      type:          'event',
      title:         '📅 New Event: ${title.trim()}',
      body:          '${location.trim()} • ${time.trim()}',
      excludeUserId: organizerId,
    );
  }

  /// RSVP to an event.
  ///
  /// **Offline**: queues the RPC call and updates the local cache immediately.
  Future<void> rsvpEvent(String eventId, String userId, bool going) async {
    if (_connectivity.isOffline) {
      // Update local cache so the button toggles immediately
      await _db.updateEventRsvp(eventId, going);

      await _db.enqueuePendingAction(
        actionType:  'rsvp_event',
        payloadJson: jsonEncode({
          'event_id': eventId,
          'user_id':  userId,
          'going':    going,
        }),
      );
      return;
    }

    try {
      await supabase.rpc('toggle_rsvp', params: {
        'p_event_id': eventId,
        'p_user_id':  userId,
        'p_going':    going,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteEvent(String id) async {
    await _db.deleteEvent(id);

    if (_connectivity.isOnline) {
      try {
        await supabase.from('events').delete().eq('id', id);
      } catch (_) {}
    } else {
      await _db.enqueuePendingAction(
        actionType:  'delete_event',
        payloadJson: jsonEncode({'id': id}),
      );
    }
  }

  Future<void> syncDeletions() async {
    if (_connectivity.isOffline) return;
    try {
      final deletedItems = await _db.getDeletedItems();
      for (final id in deletedItems['events'] ?? []) {
        try {
          await supabase.from('events').delete().eq('id', id);
        } catch (_) {}
      }
    } catch (_) {}
  }
}
