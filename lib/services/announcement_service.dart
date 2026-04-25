import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement_model.dart';
import '../models/isar_announcement.dart';
import '../services/connectivity_service.dart';
import '../services/local_database_service.dart';
import 'notification_service.dart';
import 'supabase_client.dart';

class AnnouncementService {
  final LocalDatabaseService _db;
  final ConnectivityService _connectivity;

  AnnouncementService(this._db, this._connectivity);

  Stream<List<Announcement>> getAnnouncements({String? type}) {
    final controller = StreamController<List<Announcement>>.broadcast();

    Future<void> _run() async {
      try {
        final cached = await _db.getCachedAnnouncements(type: type);
        if (!controller.isClosed) {
          controller.add(cached.map((a) => a.toAnnouncement()).toList());
        }
      } catch (_) {}

      if (!_connectivity.isOnline) return;

      try {
        final rows = await supabase
            .from('announcements')
            .select()
            .order('posted_at', ascending: false)
            .timeout(const Duration(seconds: 10));

        var list = (rows as List).map((r) => Announcement.fromMap(r)).toList();
        if (type != null && type != 'All') {
          list = list.where((a) => a.type == type).toList();
        }

        final isarAnns = list.map((a) => IsarAnnouncement.fromAnnouncement(a)).toList();
        await _db.cacheAnnouncements(isarAnns);
        if (!controller.isClosed) controller.add(list);

        supabase
            .channel('announcements_changes')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'announcements',
              callback: (_) async {
                try {
                  final updated = await supabase
                      .from('announcements')
                      .select()
                      .order('posted_at', ascending: false)
                      .timeout(const Duration(seconds: 10));

                  var updatedList =
                      (updated as List).map((r) => Announcement.fromMap(r)).toList();
                  if (type != null && type != 'All') {
                    updatedList = updatedList.where((a) => a.type == type).toList();
                  }
                  final isarUpdated = updatedList
                      .map((a) => IsarAnnouncement.fromAnnouncement(a))
                      .toList();
                  await _db.cacheAnnouncements(isarUpdated);
                  if (!controller.isClosed) controller.add(updatedList);
                } catch (_) {}
              },
            )
            .subscribe();
      } catch (e) {
        print('Error fetching announcements: $e');
      }
    }

    _run();
    return controller.stream;
  }

  Future<void> postAnnouncement({
    required String title,
    required String content,
    required String postedBy,
    required String postedById,
    required String type,
  }) async {
    if (title.trim().isEmpty) throw Exception('Title cannot be empty');
    if (content.trim().isEmpty) throw Exception('Content cannot be empty');
    if (_connectivity.isOffline) throw Exception('Cannot post offline.');

    await supabase.from('announcements').insert({
      'title': title.trim(),
      'content': content.trim(),
      'posted_by': postedBy,
      'posted_by_id': postedById,
      'type': type,
    }).timeout(const Duration(seconds: 10));

    // Push notification to all other users
    NotificationService.send(
      type: 'announcement',
      title: '📢 New Announcement',
      body: title.trim(),
      excludeUserId: postedById,
    );
  }

  Future<void> bookmarkToggle(String userId, String announcementId, bool add) async {
    if (_connectivity.isOffline) {
      await _db.updateAnnouncementBookmark(announcementId, add);
      return;
    }
    try {
      if (add) {
        await supabase.rpc('append_bookmark',
            params: {'user_id': userId, 'ann_id': announcementId});
      } else {
        await supabase.rpc('remove_bookmark',
            params: {'user_id': userId, 'ann_id': announcementId});
      }
      await _db.updateAnnouncementBookmark(announcementId, add);
    } catch (e) {
      await _db.updateAnnouncementBookmark(announcementId, add);
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    await _db.deleteAnnouncement(id);
    if (_connectivity.isOnline) {
      try {
        await supabase.from('announcements').delete().eq('id', id);
      } catch (_) {}
    }
  }

  Future<void> syncDeletions() async {
    if (_connectivity.isOffline) return;
    try {
      final deletedItems = await _db.getDeletedItems();
      for (final id in deletedItems['announcements'] ?? []) {
        try {
          await supabase.from('announcements').delete().eq('id', id);
        } catch (_) {}
      }
    } catch (_) {}
  }
}
