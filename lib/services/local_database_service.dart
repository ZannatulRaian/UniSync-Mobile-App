import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/isar_announcement.dart';
import '../models/isar_event.dart';
import '../models/isar_chat.dart';
import '../models/isar_resource.dart';
import '../models/isar_pending_action.dart';

class LocalDatabaseService {
  static Isar? _isar;
  static bool _initialized = false;

  static Isar get isar {
    if (_isar == null || !_isar!.isOpen) {
      throw StateError(
          'LocalDatabaseService not initialized. Call initialize() first.');
    }
    return _isar!;
  }

  static Future<void> initialize() async {
    if (_initialized && _isar != null && _isar!.isOpen) return;

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [
        IsarAnnouncementSchema,
        IsarEventSchema,
        IsarChatRoomSchema,
        IsarChatMessageSchema,
        IsarResourceSchema,
        IsarPendingActionSchema,
      ],
      directory: dir.path,
      name: 'unisync_db',
    );

    _initialized = true;
  }

  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
    _initialized = false;
  }

  // ============ ANNOUNCEMENTS ============

  Future<void> cacheAnnouncements(List<IsarAnnouncement> announcements) async {
    await isar.writeTxn(() async {
      for (var ann in announcements) {
        // Upsert by remoteId — prevents duplicates on repeated fetches
        final existing = await isar.isarAnnouncements
            .filter()
            .remoteIdEqualTo(ann.remoteId)
            .findFirst();
        if (existing != null) {
          ann.id = existing.id;
          ann.isBookmarked = existing.isBookmarked; // preserve local bookmark
        }
        ann.cachedAt = DateTime.now();
        await isar.isarAnnouncements.put(ann);
      }
    });
  }

  Future<List<IsarAnnouncement>> getCachedAnnouncements(
      {String? type}) async {
    final all = await isar.isarAnnouncements
        .filter()
        .isDeletedEqualTo(false)
        .findAll();

    if (type != null && type != 'All') {
      return all.where((a) => a.type == type).toList();
    }
    return all;
  }

  Future<void> deleteAnnouncement(String remoteId) async {
    await isar.writeTxn(() async {
      final ann = await isar.isarAnnouncements
          .filter()
          .remoteIdEqualTo(remoteId)
          .findFirst();
      if (ann != null) {
        ann.isDeleted = true;
        await isar.isarAnnouncements.put(ann);
      }
    });
  }

  Future<void> updateAnnouncementBookmark(
      String remoteId, bool isBookmarked) async {
    await isar.writeTxn(() async {
      final ann = await isar.isarAnnouncements
          .filter()
          .remoteIdEqualTo(remoteId)
          .findFirst();
      if (ann != null) {
        ann.isBookmarked = isBookmarked;
        await isar.isarAnnouncements.put(ann);
      }
    });
  }

  // ============ EVENTS ============

  Future<void> cacheEvents(List<IsarEvent> events) async {
    await isar.writeTxn(() async {
      for (var event in events) {
        // Upsert by remoteId — prevents duplicates
        final existing = await isar.isarEvents
            .filter()
            .remoteIdEqualTo(event.remoteId)
            .findFirst();
        if (existing != null) {
          event.id = existing.id;
          event.isRSVPed = existing.isRSVPed; // preserve local RSVP state
        }
        event.cachedAt = DateTime.now();
        await isar.isarEvents.put(event);
      }
    });
  }

  Future<List<IsarEvent>> getCachedEvents() async {
    return await isar.isarEvents.filter().isDeletedEqualTo(false).findAll();
  }

  Future<void> deleteEvent(String remoteId) async {
    await isar.writeTxn(() async {
      final event = await isar.isarEvents
          .filter()
          .remoteIdEqualTo(remoteId)
          .findFirst();
      if (event != null) {
        event.isDeleted = true;
        await isar.isarEvents.put(event);
      }
    });
  }

  // ============ CHAT ROOMS ============

  Future<void> cacheChatRooms(List<IsarChatRoom> rooms) async {
    await isar.writeTxn(() async {
      for (var room in rooms) {
        // Upsert by remoteId — prevents duplicates
        final existing = await isar.isarChatRooms
            .filter()
            .remoteIdEqualTo(room.remoteId)
            .findFirst();
        if (existing != null) {
          room.id = existing.id;
        }
        room.cachedAt = DateTime.now();
        await isar.isarChatRooms.put(room);
      }
    });
  }

  Future<List<IsarChatRoom>> getCachedChatRooms() async {
    return await isar.isarChatRooms
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
  }

  Future<void> deleteChatRoom(String remoteId) async {
    await isar.writeTxn(() async {
      final room = await isar.isarChatRooms
          .filter()
          .remoteIdEqualTo(remoteId)
          .findFirst();
      if (room != null) {
        room.isDeleted = true;
        await isar.isarChatRooms.put(room);
      }
    });
  }

  // ============ CHAT MESSAGES ============

  Future<void> cacheMessages(List<IsarChatMessage> messages) async {
    await isar.writeTxn(() async {
      for (var msg in messages) {
        // Upsert by remoteId — prevents duplicates
        final existing = await isar.isarChatMessages
            .filter()
            .remoteIdEqualTo(msg.remoteId)
            .findFirst();
        if (existing != null) {
          msg.id = existing.id;
        }
        msg.cachedAt = DateTime.now();
        await isar.isarChatMessages.put(msg);
      }
    });
  }

  Future<List<IsarChatMessage>> getCachedMessages(String roomId) async {
    return await isar.isarChatMessages
        .filter()
        .roomIdEqualTo(roomId)
        .and()
        .isDeletedEqualTo(false)
        .findAll();
  }

  Future<void> deleteMessage(String remoteId) async {
    await isar.writeTxn(() async {
      final msg = await isar.isarChatMessages
          .filter()
          .remoteIdEqualTo(remoteId)
          .findFirst();
      if (msg != null) {
        msg.isDeleted = true;
        await isar.isarChatMessages.put(msg);
      }
    });
  }

  // ============ RESOURCES ============

  Future<void> cacheResources(List<IsarResource> resources) async {
    await isar.writeTxn(() async {
      for (var res in resources) {
        // Upsert by remoteId — prevents duplicates
        final existing = await isar.isarResources
            .filter()
            .remoteIdEqualTo(res.remoteId)
            .findFirst();
        if (existing != null) {
          res.id = existing.id;
          res.isBookmarked = existing.isBookmarked; // preserve local bookmark
        }
        res.cachedAt = DateTime.now();
        await isar.isarResources.put(res);
      }
    });
  }

  Future<List<IsarResource>> getCachedResources(
      {String? department, String? type}) async {
    final all =
        await isar.isarResources.filter().isDeletedEqualTo(false).findAll();

    var filtered = all;
    if (department != null && department != 'All') {
      filtered = filtered.where((r) => r.department == department).toList();
    }
    if (type != null && type != 'All') {
      filtered = filtered.where((r) => r.type == type).toList();
    }
    return filtered;
  }

  Future<void> deleteResource(String remoteId) async {
    await isar.writeTxn(() async {
      final res = await isar.isarResources
          .filter()
          .remoteIdEqualTo(remoteId)
          .findFirst();
      if (res != null) {
        res.isDeleted = true;
        await isar.isarResources.put(res);
      }
    });
  }

  Future<void> updateResourceBookmark(
      String remoteId, bool isBookmarked) async {
    await isar.writeTxn(() async {
      final res = await isar.isarResources
          .filter()
          .remoteIdEqualTo(remoteId)
          .findFirst();
      if (res != null) {
        res.isBookmarked = isBookmarked;
        await isar.isarResources.put(res);
      }
    });
  }

  Future<List<IsarResource>> getBookmarkedResources() async {
    return await isar.isarResources
        .filter()
        .isDeletedEqualTo(false)
        .and()
        .isBookmarkedEqualTo(true)
        .findAll();
  }

  // ============ PENDING ACTION QUEUE ============

  /// Enqueue an action to be replayed when connectivity is restored.
  Future<IsarPendingAction> enqueuePendingAction({
    required String actionType,
    required String payloadJson,
    String localTempId = '',
  }) async {
    final action = IsarPendingAction(
      actionType: actionType,
      payloadJson: payloadJson,
      createdAt: DateTime.now(),
      localTempId: localTempId,
    );
    await isar.writeTxn(() async {
      await isar.isarPendingActions.put(action);
    });
    return action;
  }

  /// All pending (not yet synced) actions, oldest first.
  Future<List<IsarPendingAction>> getPendingActions() async {
    final all = await isar.isarPendingActions
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
    all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return all;
  }

  /// Mark a pending action as successfully synced.
  Future<void> markActionSynced(Id actionId) async {
    await isar.writeTxn(() async {
      final action = await isar.isarPendingActions.get(actionId);
      if (action != null) {
        action.isSynced = true;
        await isar.isarPendingActions.put(action);
      }
    });
  }

  /// Increment retry count for a failed action.
  Future<void> incrementActionRetry(Id actionId) async {
    await isar.writeTxn(() async {
      final action = await isar.isarPendingActions.get(actionId);
      if (action != null) {
        action.retryCount += 1;
        await isar.isarPendingActions.put(action);
      }
    });
  }


  // ============ EXTRA HELPERS (used by services directly) ============

  /// Delete all optimistic `pending_*` chat messages in [roomId] whose content
  /// is present in [serverContents] — meaning the real message is now on the
  /// server and the local placeholder is no longer needed.
  Future<void> removeSyncedOptimisticMessages(
      String roomId, Set<String> serverContents) async {
    final pending = await isar.isarChatMessages
        .filter()
        .roomIdEqualTo(roomId)
        .and()
        .remoteIdStartsWith('pending_')
        .findAll();

    await isar.writeTxn(() async {
      for (final msg in pending) {
        if (serverContents.contains(msg.content.trim())) {
          if (msg.id != null) {
            await isar.isarChatMessages.delete(msg.id!);
          }
        }
      }
    });
  }

  /// Update the local RSVP state for [eventId] without a network call.
  Future<void> updateEventRsvp(String eventId, bool isRSVPed) async {
    await isar.writeTxn(() async {
      final event = await isar.isarEvents
          .filter()
          .remoteIdEqualTo(eventId)
          .findFirst();
      if (event != null) {
        event.isRSVPed = isRSVPed;
        await isar.isarEvents.put(event);
      }
    });
  }

  /// Remove all synced actions (cleanup call after successful sync).
  Future<void> clearSyncedActions() async {
    await isar.writeTxn(() async {
      final synced = await isar.isarPendingActions
          .filter()
          .isSyncedEqualTo(true)
          .findAll();
      for (final a in synced) {
        if (a.id != null) await isar.isarPendingActions.delete(a.id!);
      }
    });
  }

  /// Returns count of unsent pending actions (useful for UI badge).
  Future<int> pendingActionCount() async {
    return await isar.isarPendingActions
        .filter()
        .isSyncedEqualTo(false)
        .count();
  }

  // ============ UTILITY ============

  Future<void> clearAllCache() async {
    await isar.writeTxn(() async {
      await isar.isarAnnouncements.clear();
      await isar.isarEvents.clear();
      await isar.isarChatRooms.clear();
      await isar.isarChatMessages.clear();
      await isar.isarResources.clear();
      // Note: does NOT clear pending actions — those survive a cache wipe
    });
  }

  Future<Map<String, List<String>>> getDeletedItems() async {
    return {
      'announcements': (await isar.isarAnnouncements
              .filter()
              .isDeletedEqualTo(true)
              .findAll())
          .map((a) => a.remoteId)
          .toList(),
      'events': (await isar.isarEvents
              .filter()
              .isDeletedEqualTo(true)
              .findAll())
          .map((e) => e.remoteId)
          .toList(),
      'messages': (await isar.isarChatMessages
              .filter()
              .isDeletedEqualTo(true)
              .findAll())
          .map((m) => m.remoteId)
          .toList(),
      'resources': (await isar.isarResources
              .filter()
              .isDeletedEqualTo(true)
              .findAll())
          .map((r) => r.remoteId)
          .toList(),
    };
  }
}
