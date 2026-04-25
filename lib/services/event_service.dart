import 'dart:async';
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
    if (_connectivity.isOffline) throw Exception('Cannot create event offline.');

    const colors = ['1A56DB', '0E9F6E', 'E3A008', 'E02424', '9061F9', '3F83F8'];
    final color = colors[DateTime.now().millisecond % colors.length];

    await supabase.from('events').insert({
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'location': location.trim(),
      'date': date.toIso8601String(),
      'time': time.trim(),
      'attendees': 0,
      'organizer': organizer,
      'organizer_id': organizerId,
      'image_color': color,
    }).timeout(const Duration(seconds: 10));

    // Push notification to all other users
    NotificationService.send(
      type: 'event',
      title: '📅 New Event: ${title.trim()}',
      body: '$location • $time',
      excludeUserId: organizerId,
    );
  }

  Future<void> rsvpEvent(String eventId, String userId, bool going) async {
    if (_connectivity.isOffline) return;
    try {
      await supabase.rpc('toggle_rsvp', params: {
        'p_event_id': eventId,
        'p_user_id': userId,
        'p_going': going,
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
