import 'dart:async';
import 'dart:convert';
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<T> _dedupe<T>(List<T> items, String Function(T) idOf) {
    final seen = <String>{};
    return items.where((i) => seen.add(idOf(i))).toList();
  }

  // ── Base room stream ───────────────────────────────────────────────────────
  // Uses select() + realtime subscription instead of .stream() because
  // .stream() requires a stable WebSocket that can fail on real devices
  // behind carrier NAT / firewalls — causing infinite shimmer loading.
  Stream<List<ChatRoom>> getRooms(String userId) {
    final controller = StreamController<List<ChatRoom>>.broadcast();

    Future<void> _run() async {
      if (userId.isEmpty) {
        if (!controller.isClosed) controller.add([]);
        return;
      }

      // Step 1 — emit cache immediately (works offline too)
      try {
        final cached = await _db.getCachedChatRooms();
        final filtered = cached
            .where((r) => r.memberIds.contains(userId))
            .map((r) => r.toChatRoom())
            .toList();
        if (!controller.isClosed) {
          controller.add(_dedupe(filtered, (r) => r.id));
        }
      } catch (e) {
        print('Error loading cached rooms: $e');
      }

      if (!_connectivity.isOnline) return;

      // Step 2 — fetch fresh data with a regular HTTP select()
      Future<void> _fetchAndEmit() async {
        try {
          final rows = await supabase
              .from('chat_rooms')
              .select()
              .order('last_message_time', ascending: false)
              .timeout(const Duration(seconds: 10));

          final list = (rows as List)
              .map((r) => ChatRoom.fromMap(r))
              .where((r) => r.memberIds.contains(userId))
              .toList();
          final deduped = _dedupe(list, (r) => r.id);

          final isarRooms =
              deduped.map((r) => IsarChatRoom.fromChatRoom(r)).toList();
          await _db.cacheChatRooms(isarRooms);

          if (!controller.isClosed) controller.add(deduped);
        } catch (e) {
          print('Error fetching rooms: $e');
          // Don't add error — cached data is already showing
        }
      }

      await _fetchAndEmit();

      // Step 3 — subscribe to realtime changes and re-fetch on any change
      supabase
          .channel('chat_rooms_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chat_rooms',
            callback: (_) => _fetchAndEmit(),
          )
          .subscribe();
    }

    _run();
    return controller.stream;
  }

  // ── Fetch photo URLs for every member ─────────────────────────────────────
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

  Future<List<ChatRoom>> _enrichWithPhotos(List<ChatRoom> rooms) async {
    final photoMap = await _fetchMemberPhotos(rooms);
    return rooms.map((room) {
      final urls = room.memberIds.map((id) => photoMap[id]).toList();
      return ChatRoom(
        id:               room.id,
        name:             room.name,
        lastMessage:      room.lastMessage,
        lastMessageTime:  room.lastMessageTime,
        isGroup:          room.isGroup,
        memberIds:        room.memberIds,
        memberNames:      room.memberNames,
        memberPhotoUrls:  urls,
        avatarColor:      room.avatarColor,
        unreadCount:      room.unreadCount,
      );
    }).toList();
  }

  // ── Messages ───────────────────────────────────────────────────────────────
  Stream<List<ChatMessage>> getMessages(String roomId) {
    final controller = StreamController<List<ChatMessage>>.broadcast();

    Future<void> _run() async {
      // Emit cached messages first (includes optimistic pending_ ones)
      try {
        final cached = await _db.getCachedMessages(roomId);
        if (!controller.isClosed) {
          controller.add(cached.map((m) => m.toChatMessage()).toList());
        }
      } catch (e) {
        print('Error loading cached messages: $e');
      }

      if (!_connectivity.isOnline) return;

      try {
        final rows = await supabase
            .from('chat_messages')
            .select()
            .eq('room_id', roomId)
            .order('created_at', ascending: true);

        final messages =
            (rows as List).map((r) => ChatMessage.fromMap(r)).toList();

        // Replace any optimistic pending_ messages with real ones
        final isarMessages =
            messages.map((m) => IsarChatMessage.fromChatMessage(m)).toList();
        await _db.cacheMessages(isarMessages);

        // Clean up any pending_ messages for this room that are now on the server
        await _removeSyncedOptimisticMessages(roomId, messages);

        if (!controller.isClosed) controller.add(messages);

        // Realtime subscription
        supabase
            .channel('room_$roomId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'chat_messages',
              filter: PostgresChangeFilter(
                type:   PostgresChangeFilterType.eq,
                column: 'room_id',
                value:  roomId,
              ),
              callback: (payload) async {
                try {
                  final msg = ChatMessage.fromMap(payload.newRecord);
                  final isarMsg = IsarChatMessage.fromChatMessage(msg);
                  await _db.cacheMessages([isarMsg]);

                  final updated = await _db.getCachedMessages(roomId);
                  if (!controller.isClosed) {
                    controller
                        .add(updated.map((m) => m.toChatMessage()).toList());
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

    _run();
    return controller.stream;
  }

  /// After reconnecting and fetching real server messages, remove optimistic
  /// copies whose content already appears in the server results.
  Future<void> _removeSyncedOptimisticMessages(
      String roomId, List<ChatMessage> serverMessages) async {
    final serverContents =
        serverMessages.map((m) => m.content.trim()).toSet();
    await _db.removeSyncedOptimisticMessages(roomId, serverContents);
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
      throw Exception(
          'Cannot create a chat room while offline. Please check your connection.');
    }

    if (!isGroup && memberIds.length == 2) {
      final existing = await supabase
          .from('chat_rooms')
          .select()
          .eq('is_group', false)
          .contains('member_ids', memberIds);
      if ((existing as List).isNotEmpty) {
        final room = ChatRoom.fromMap(existing.first);
        final enriched = await _enrichWithPhotos([room]);
        return enriched.first;
      }
    }

    const colors = [
      '1A56DB', '0E9F6E', 'E3A008', '9061F9', 'E02424', '3F83F8'
    ];
    final color = colors[DateTime.now().millisecond % colors.length];

    final data = {
      'name':         name.trim(),
      'last_message': '',
      'is_group':     isGroup,
      'member_ids':   memberIds,
      'member_names': memberNames,
      'avatar_color': color,
    };
    final res =
        await supabase.from('chat_rooms').insert(data).select().single();
    final room = ChatRoom.fromMap(res);

    final isarRoom = IsarChatRoom.fromChatRoom(room);
    await _db.cacheChatRooms([isarRoom]);

    final enriched = await _enrichWithPhotos([room]);
    return enriched.first;
  }

  // ── Unread tracking ────────────────────────────────────────────────────────
  Future<void> markRoomAsRead(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'last_seen_$roomId', DateTime.now().toIso8601String());
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
        if (lastSeenStr == null) {
          final cached = await _db.getCachedMessages(roomId);
          return cached.where((m) => m.senderId != uid).length;
        }
        final lastSeen = DateTime.parse(lastSeenStr);
        final cached = await _db.getCachedMessages(roomId);
        return cached
            .where((m) =>
                m.senderId != uid && m.timestamp.isAfter(lastSeen))
            .length;
      }
    } catch (_) {
      return 0;
    }
  }

  // ── Rooms with unread + photo enrichment ──────────────────────────────────
  Stream<List<ChatRoom>> getRoomsWithUnread(String userId) {
    final controller = StreamController<List<ChatRoom>>.broadcast();

    Future<void> enrichRooms(List<ChatRoom> rooms) async {
      final unique = _dedupe(rooms, (r) => r.id);
      final withPhotos = _connectivity.isOnline
          ? await _enrichWithPhotos(unique)
          : unique;

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

    controller.onCancel = () => sub?.cancel();
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
    _onlineIds
      ..clear()
      ..addAll(ids);
    if (!_onlineController.isClosed) {
      _onlineController.add(Set.from(_onlineIds));
    }
  }

  void joinPresence(String userId, String userName) {
    if (_connectivity.isOffline) return;

    leavePresence();
    _presenceChannel = supabase.channel('global_presence');
    _presenceChannel!
        .onPresenceSync((_) => _syncOnline())
        .onPresenceJoin((_) => _syncOnline())
        .onPresenceLeave((_) => _syncOnline())
        .subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        try {
          await _presenceChannel!
              .track({'user_id': userId, 'name': userName});
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

  // ── Send message ───────────────────────────────────────────────────────────
  ///
  /// **Online**: writes to Supabase immediately.
  /// **Offline**: queues the send and inserts an optimistic local message
  /// (prefixed `pending_`) so the UI shows it straight away.
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

    if (_connectivity.isOffline) {
      final tempId =
          'pending_${DateTime.now().millisecondsSinceEpoch}_$senderId';
      final now = DateTime.now();

      // Persist optimistic message locally so it shows in the UI
      final optimistic = IsarChatMessage(
        remoteId:   tempId,
        roomId:     roomId,
        senderId:   senderId,
        senderName: senderName,
        content:    safe,
        timestamp:  now,
        cachedAt:   now,
      );
      await _db.cacheMessages([optimistic]);

      // Queue the actual network call
      await _db.enqueuePendingAction(
        actionType: 'send_message',
        payloadJson: jsonEncode({
          'room_id':      roomId,
          'sender_id':    senderId,
          'sender_name':  senderName,
          'content':      safe,
          'created_at':   now.toIso8601String(),
          'local_temp_id': tempId,
        }),
        localTempId: tempId,
      );

      print('[ChatService] Message queued offline — will send when online');
      return;
    }

    // ── Online: validate membership first ──────────────────────────────────
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

    final now = DateTime.now().toIso8601String();
    await supabase.from('chat_messages').insert({
      'room_id':     roomId,
      'sender_id':   senderId,
      'sender_name': senderName,
      'content':     safe,
      'created_at':  now,
    });
    await supabase.from('chat_rooms').update({
      'last_message': safe.length > 60 ? '${safe.substring(0, 60)}...' : safe,
      'last_message_time': now,
    }).eq('id', roomId);

    NotificationService.send(
      type:          'chat',
      title:         '💬 $senderName',
      body:          safe.length > 80 ? '${safe.substring(0, 80)}...' : safe,
      excludeUserId: senderId,
    );
  }

  // ── Delete message ─────────────────────────────────────────────────────────
  Future<void> deleteMessage(String messageId) async {
    await _db.deleteMessage(messageId);

    if (_connectivity.isOnline) {
      try {
        await supabase.from('chat_messages').delete().eq('id', messageId);
      } catch (e) {
        print('Error deleting message: $e');
      }
    } else {
      // Only queue server deletion for real (non-pending) messages
      if (!messageId.startsWith('pending_')) {
        await _db.enqueuePendingAction(
          actionType:  'delete_message',
          payloadJson: jsonEncode({'id': messageId}),
        );
      }
    }
  }

  /// Sync message deletions when connection is restored.
  Future<void> syncDeletions() async {
    if (_connectivity.isOffline) return;
    try {
      final deletedItems = await _db.getDeletedItems();
      for (final id in deletedItems['messages'] ?? []) {
        if (id.startsWith('pending_')) continue; // never existed on server
        try {
          await supabase.from('chat_messages').delete().eq('id', id);
        } catch (e) {
          print('Failed to sync deletion for $id: $e');
        }
      }
    } catch (e) {
      print('Error syncing message deletions: $e');
    }
  }
}
