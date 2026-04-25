import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/isar_announcement.dart';
import '../models/isar_event.dart';
import '../models/isar_chat.dart';
import '../models/isar_resource.dart';

class LocalDatabaseService {
  static late Isar isar;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();

    isar = await Isar.open(
      [
        IsarAnnouncementSchema,
        IsarEventSchema,
        IsarChatRoomSchema,
        IsarChatMessageSchema,
        IsarResourceSchema,
      ],
      directory: dir.path,
    );

    _initialized = true;
  }

  static Future<void> close() async {
    await isar.close();
  }

  // ============ ANNOUNCEMENTS ============

  Future<void> cacheAnnouncements(List<IsarAnnouncement> announcements) async {
    await isar.writeTxn(() async {
      for (var ann in announcements) {
        ann.cachedAt = DateTime.now();
        await isar.isarAnnouncements.put(ann);
      }
    });
  }

  Future<List<IsarAnnouncement>> getCachedAnnouncements({String? type}) async {
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

  Future<void> updateAnnouncementBookmark(String remoteId, bool isBookmarked) async {
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
        event.cachedAt = DateTime.now();
        await isar.isarEvents.put(event);
      }
    });
  }

  Future<List<IsarEvent>> getCachedEvents() async {
    return await isar.isarEvents
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
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
        res.cachedAt = DateTime.now();
        await isar.isarResources.put(res);
      }
    });
  }

  Future<List<IsarResource>> getCachedResources({String? department, String? type}) async {
    final all = await isar.isarResources
        .filter()
        .isDeletedEqualTo(false)
        .findAll();

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

  // ============ UTILITY ============

  Future<void> clearAllCache() async {
    await isar.writeTxn(() async {
      await isar.isarAnnouncements.clear();
      await isar.isarEvents.clear();
      await isar.isarChatRooms.clear();
      await isar.isarChatMessages.clear();
      await isar.isarResources.clear();
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
