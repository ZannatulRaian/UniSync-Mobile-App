import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../models/isar_chat.dart';
import '../services/connectivity_service.dart';
import '../services/local_database_service.dart';
import 'supabase_client.dart';
import 'notification_service.dart';

class ChatService {
  static const _maxMessageLength = 2000;

  final LocalDatabaseService _db;
  final ConnectivityService _connectivity;

  ChatService(this._db, this._connectivity);

  // ── Base room stream (no photo enrichment) ─────────────────────────────────
  Stream<List<ChatRoom>> getRooms(String userId) async* {
    // Yield cached rooms first
    final cached = await _db.getCachedChatRooms();
    final filtered = cached
        .where((r) => r.memberIds.contains(userId))
        .map((r) => r.toChatRoom())
        .toList();
    yield filtered;

    // If online, fetch fresh data
    if (_connectivity.isOnline) {
      try {
        await for (final rows in supabase
            .from('chat_rooms')
            .stream(primaryKey: ['id'])
            .order('last_message_time', ascending: false)) {
          
          final list = rows
              .map((r) => ChatRoom.fromMap(r))
              .where((r) => r.memberIds.contains(userId))
              .toList();

          // DEDUPLICATE by ID (fix for duplicate rooms)
          final seen = <String>{};
          final deduped = <ChatRoom>[];
          for (final room in list) {
            if (!seen.contains(room.id)) {
              seen.add(room.id);
              deduped.add(room);
            }
          }

          // Cache the fresh data
          final isarRooms = deduped
              .map((r) => IsarChatRoom.fromChatRoom(r))
              .toList();
          await _db.cacheChatRooms(isarRooms);

          yield deduped;
        }
      } catch (e) {
        print('Error fetching rooms: $e');
      }
    }
  }

  // ── Fetch photo URLs for every member from the users table ─────────────
  Future<Map<String, String?>> _fetchMemberPhotos(
      List<ChatRoom> rooms) async {
    final allIds = <String>{};
    for (final r in rooms) {
      allIds.addAll(r.memberIds);
    }
    if (allIds.isEmpty) return {};

    try {
      final rows = await supabase
          .from('users')
          .select('id, photo_url')
          .inFilter('id', allIds.toList());
      return {
        for (final row in (rows as List))
          row['id'] as String: row['photo_url'] as String?,
      };
    } catch (_) {
      return {};
    }
  }

  // ── Enrich a list of rooms with live photo URLs ────────────────────────────
  Future<List<ChatRoom>> _enrichWithPhotos(List<ChatRoom> rooms) async {
    final photoMap = await _fetchMemberPhotos(rooms);
    return rooms.map((room) {
      final urls = room.memberIds
          .map((id) => photoMap[id])
          .toList();
      return ChatRoom(
        id: room.id,
        name: room.name,
        lastMessage: room.lastMessage,
        lastMessageTime: room.lastMessageTime,
        isGroup: room.isGroup,
        memberIds: room.memberIds,
        memberNames: room.memberNames,
        memberPhotoUrls: urls,
        avatarColor: room.avatarColor,
        unreadCount: room.unreadCount,
      );
    }).toList();
  }

  // ── Messages ───────────────────────────────────────────────────────────────
  Stream<List<ChatMessage>> getMessages(String roomId) {
    final controller = StreamController<List<ChatMessage>>.broadcast();

    Future<void> _run() async {
      // Emit cached messages first
      try {
        final cached = await _db.getCachedMessages(roomId);
        if (!controller.isClosed) {
          controller.add(cached.map((m) => m.toChatMessage()).toList());
        }
      } catch (e) {
        print('Error loading cached messages: $e');
      }

      // If online, fetch and sync messages
      if (_connectivity.isOnline) {
        try {
          final rows = await supabase
              .from('chat_messages')
              .select()
              .eq('room_id', roomId)
              .order('created_at', ascending: true);

          final messages = (rows as List)
              .map((r) => ChatMessage.fromMap(r))
              .toList();

          // Cache the fresh data
          final isarMessages =
              messages.map((m) => IsarChatMessage.fromChatMessage(m)).toList();
          await _db.cacheMessages(isarMessages);

          if (!controller.isClosed) controller.add(messages);

          // Setup realtime subscription — use controller.add instead of yield
          supabase
              .channel('room_$roomId')
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'chat_messages',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'room_id',
                  value: roomId,
                ),
                callback: (payload) async {
                  try {
                    final msg = ChatMessage.fromMap(payload.newRecord);

                    // Cache the new message
                    final isarMsg = IsarChatMessage.fromChatMessage(msg);
                    await _db.cacheMessages([isarMsg]);

                    // Emit updated list
                    final updated = await _db.getCachedMessages(roomId);
                    if (!controller.isClosed) {
                      controller.add(updated.map((m) => m.toChatMessage()).toList());
                    }
                  } catch (_) {}
                },
              )
              .subscribe();
        } catch (e) {
          print('Error fetching messages: $e');
          if (!controller.isClosed) controller.addError(e);
        }
      }
    }

    _run();
    return controller.stream;
  }

  // ── Create room ────────────────────────────────────────────────────────────
  Future<ChatRoom> createRoom({
    required String name,
    required bool isGroup,
    required List<String> memberIds,
    required List<String> memberNames,
    required String createdById,
  }) async {
    if (_connectivity.isOffline) {
      throw Exception('Cannot create chat offline. Please check your connection.');
    }

    if (!isGroup && memberIds.length == 2) {
      final existing = await supabase
          .from('chat_rooms')
          .select()
          .eq('is_group', false)
          .contains('member_ids', memberIds);
      if (existing.isNotEmpty) {
        final room = ChatRoom.fromMap(existing.first);
        final enriched = await _enrichWithPhotos([room]);
        return enriched.first;
      }
    }

    const colors = ['1A56DB', '0E9F6E', 'E3A008', '9061F9', 'E02424', '3F83F8'];
    final color = colors[DateTime.now().millisecond % colors.length];

    final data = {
      'name': name.trim(),
      'last_message': '',
      'is_group': isGroup,
      'member_ids': memberIds,
      'member_names': memberNames,
      'avatar_color': color,
    };
    final res = await supabase.from('chat_rooms').insert(data).select().single();
    final room = ChatRoom.fromMap(res);
    
    // Cache the new room
    final isarRoom = IsarChatRoom.fromChatRoom(room);
    await _db.cacheChatRooms([isarRoom]);
    
    final enriched = await _enrichWithPhotos([room]);
    return enriched.first;
  }

  // ── Unread tracking ────────────────────────────────────────────────────────
  Future<void> markRoomAsRead(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_seen_$roomId', DateTime.now().toIso8601String());
  }

  Future<int> getUnreadCount(String roomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeenStr = prefs.getString('last_seen_$roomId');
      final uid = supabase.auth.currentUser?.id ?? '';
      
      if (_connectivity.isOnline) {
        if (lastSeenStr == null) {
          final rows = await supabase
              .from('chat_messages')
              .select('id, sender_id')
              .eq('room_id', roomId);
          return (rows as List).where((r) => r['sender_id'] != uid).length;
        }
        final lastSeen = DateTime.parse(lastSeenStr);
        final rows = await supabase
            .from('chat_messages')
            .select('id, sender_id, created_at')
            .eq('room_id', roomId)
            .gt('created_at', lastSeen.toIso8601String());
        return (rows as List).where((r) => r['sender_id'] != uid).length;
      } else {
        // Offline: use cached messages
        if (lastSeenStr == null) {
          final cached = await _db.getCachedMessages(roomId);
          return cached.where((m) => m.senderId != uid).length;
        }
        final lastSeen = DateTime.parse(lastSeenStr);
        final cached = await _db.getCachedMessages(roomId);
        return cached
            .where((m) => m.senderId != uid && m.timestamp.isAfter(lastSeen))
            .length;
      }
    } catch (_) {
      return 0;
    }
  }

  // ── getRoomsWithUnread now also enriches with photo URLs ──────────────
  Stream<List<ChatRoom>> getRoomsWithUnread(String userId) {
    final controller = StreamController<List<ChatRoom>>.broadcast();

    Future<void> enrichRooms(List<ChatRoom> rooms) async {
      // Deduplicate by room ID before any enrichment
      final seen = <String>{};
      final unique = <ChatRoom>[];
      for (final room in rooms) {
        if (seen.add(room.id)) unique.add(room);
      }

      final withPhotos = await _enrichWithPhotos(unique);
      final enriched = <ChatRoom>[];
      for (final room in withPhotos) {
        final count = await getUnreadCount(room.id);
        room.unreadCount = count;
        enriched.add(room);
      }
      if (!controller.isClosed) controller.add(enriched);
    }

    StreamSubscription? sub;
    sub = getRooms(userId).listen(
      (rooms) => enrichRooms(rooms),
      onError: (e) {
        if (!controller.isClosed) controller.addError(e);
      },
      onDone: () {
        if (!controller.isClosed) controller.close();
        sub?.cancel();
      },
    );

    // Cancel the inner subscription when the outer stream is cancelled
    controller.onCancel = () {
      sub?.cancel();
    };

    return controller.stream;
  }

  // ── Presence ───────────────────────────────────────────────────────────────
  RealtimeChannel? _presenceChannel;
  final _onlineIds = <String>{};
  final _onlineController = StreamController<Set<String>>.broadcast();

  Stream<Set<String>> get onlineStream => _onlineController.stream;

  void _syncOnline() {
    if (_presenceChannel == null) return;
    final state = _presenceChannel!.presenceState();
    final ids = <String>{};
    for (final entry in state) {
      for (final p in entry.presences) {
        final id = p.payload['user_id']?.toString();
        if (id != null) ids.add(id);
      }
    }
    _onlineIds..clear()..addAll(ids);
    if (!_onlineController.isClosed) _onlineController.add(Set.from(_onlineIds));
  }

  void joinPresence(String userId, String userName) {
    if (_connectivity.isOffline) return; // Don't join presence when offline
    
    leavePresence();
    _presenceChannel = supabase.channel('global_presence');
    _presenceChannel!
        .onPresenceSync((_) => _syncOnline())
        .onPresenceJoin((_) => _syncOnline())
        .onPresenceLeave((_) => _syncOnline())
        .subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          await _presenceChannel!.track({'user_id': userId, 'name': userName});
        } catch (_) {}
      }
    });
  }

  void leavePresence() {
    try {
      _presenceChannel?.untrack();
    } catch (_) {}
    if (_presenceChannel != null) {
      supabase.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
  }

  Stream<Set<String>> onlineUserIds() => onlineStream;

  // ── Send message — works offline & syncs later ───────────────────────────────
  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final safe = trimmed.length > _maxMessageLength
        ? trimmed.substring(0, _maxMessageLength)
        : trimmed;

    // Check room membership
    if (_connectivity.isOnline) {
      final roomCheck = await supabase
          .from('chat_rooms')
          .select('member_ids')
          .eq('id', roomId)
          .maybeSingle();
      if (roomCheck == null) throw Exception('Chat room not found.');
      final members = List<String>.from(roomCheck['member_ids'] ?? []);
      if (!members.contains(senderId)) {
        throw Exception('You are not a member of this chat.');
      }
    }

    // If offline, cache message and sync later
    if (_connectivity.isOffline) {
      final msg = ChatMessage(
        id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        content: safe,
        timestamp: DateTime.now(),
      );
      final isarMsg = IsarChatMessage.fromChatMessage(msg);
      await _db.cacheMessages([isarMsg]);
      print('Message queued offline — will send when online');
      return;
    }

    // Send to server
    final now = DateTime.now().toIso8601String();
    await supabase.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': safe,
      'created_at': now,
    });
    await supabase.from('chat_rooms').update({
      'last_message': safe.length > 60 ? '${safe.substring(0, 60)}...' : safe,
      'last_message_time': now,
    }).eq('id', roomId);

    // Push notification to other members
    NotificationService.send(
      type: 'chat',
      title: '💬 $senderName',
      body: safe.length > 80 ? '${safe.substring(0, 80)}...' : safe,
      excludeUserId: senderId,
    );
  }

  /// Sync message deletions when connection is restored
  Future<void> syncDeletions() async {
    if (_connectivity.isOffline) return;

    try {
      final deletedItems = await _db.getDeletedItems();
      final deletedMsgIds = deletedItems['messages'] ?? [];

      for (final id in deletedMsgIds) {
        try {
          await supabase.from('chat_messages').delete().eq('id', id);
          print('Synced deletion for message: $id');
        } catch (e) {
          print('Failed to sync deletion for $id: $e');
        }
      }
    } catch (e) {
      print('Error syncing message deletions: $e');
    }
  }

  /// Delete message — syncs across offline/online
  Future<void> deleteMessage(String messageId) async {
    await _db.deleteMessage(messageId);

    if (_connectivity.isOnline) {
      try {
        await supabase.from('chat_messages').delete().eq('id', messageId);
      } catch (e) {
        print('Error deleting message: $e');
      }
    } else {
      print('Message deleted offline — will sync when online');
    }
  }
}