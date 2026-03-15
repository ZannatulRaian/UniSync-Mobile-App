import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import 'supabase_client.dart';

class ChatService {
  static const _maxMessageLength = 2000;

  Stream<List<ChatRoom>> getRooms(String userId) => supabase
      .from('chat_rooms')
      .stream(primaryKey: ['id'])
      .order('last_message_time', ascending: false)
      .map((rows) => rows
          .map(ChatRoom.fromMap)
          .where((r) => r.memberIds.contains(userId))
          .toList());

  Stream<List<ChatMessage>> getMessages(String roomId) {
    // .stream().eq() is unreliable with RLS subquery policies.
    // Use a manual fetch + realtime channel subscription instead.
    final controller = StreamController<List<ChatMessage>>.broadcast();
    List<ChatMessage> _current = [];

    // Initial fetch
    supabase
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .then((rows) {
      _current = (rows as List).map((r) => ChatMessage.fromMap(r)).toList();
      if (!controller.isClosed) controller.add(_current);
    });

    // Realtime subscription for new messages
    final channel = supabase
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
          callback: (payload) {
            try {
              final msg = ChatMessage.fromMap(payload.newRecord);
              // Avoid duplicates
              if (!_current.any((m) => m.id == msg.id)) {
                _current = [..._current, msg];
                if (!controller.isClosed) controller.add(_current);
              }
            } catch (_) {}
          },
        )
        .subscribe();

    controller.onCancel = () {
      supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  Future<ChatRoom> createRoom({
    required String name,
    required bool isGroup,
    required List<String> memberIds,
    required List<String> memberNames,
    required String createdById,
  }) async {
    if (!isGroup && memberIds.length == 2) {
      // Check if DM already exists
      final existing = await supabase
          .from('chat_rooms')
          .select()
          .eq('is_group', false)
          .contains('member_ids', memberIds);
      if (existing.isNotEmpty) return ChatRoom.fromMap(existing.first);
    }

    const colors = ['1A56DB','0E9F6E','E3A008','9061F9','E02424','3F83F8'];
    final color  = colors[DateTime.now().millisecond % colors.length];

    final data = {
      'name':              name.trim(),
      'last_message':      '',
      'is_group':          isGroup,
      'member_ids':        memberIds,
      'member_names':      memberNames,
      'avatar_color':      color,
    };
    final res = await supabase.from('chat_rooms').insert(data).select().single();
    return ChatRoom.fromMap(res);
  }

  // ── Unread message tracking ──────────────────────────────────────────
  /// Call this when the user OPENS a chat room — marks it as read now.
  Future<void> markRoomAsRead(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_seen_$roomId', DateTime.now().toIso8601String());
  }

  /// Returns how many messages in this room arrived after the last read time.
  Future<int> getUnreadCount(String roomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeenStr = prefs.getString('last_seen_$roomId');
      if (lastSeenStr == null) {
        // Never opened — count all messages not sent by current user
        final uid = supabase.auth.currentUser?.id ?? '';
        final rows = await supabase
            .from('chat_messages')
            .select('id, sender_id')
            .eq('room_id', roomId);
        return (rows as List).where((r) => r['sender_id'] != uid).length;
      }
      final lastSeen = DateTime.parse(lastSeenStr);
      final uid = supabase.auth.currentUser?.id ?? '';
      final rows = await supabase
          .from('chat_messages')
          .select('id, sender_id, created_at')
          .eq('room_id', roomId)
          .gt('created_at', lastSeen.toIso8601String());
      // Only count messages from OTHER people
      return (rows as List).where((r) => r['sender_id'] != uid).length;
    } catch (_) { return 0; }
  }

  /// Returns a stream of rooms WITH unread counts populated.
  Stream<List<ChatRoom>> getRoomsWithUnread(String userId) {
    final controller = StreamController<List<ChatRoom>>.broadcast();

    Future<void> enrichRooms(List<ChatRoom> rooms) async {
      final enriched = <ChatRoom>[];
      for (final room in rooms) {
        final count = await getUnreadCount(room.id);
        room.unreadCount = count;
        enriched.add(room);
      }
      if (!controller.isClosed) controller.add(enriched);
    }

    // Subscribe to base rooms stream
    getRooms(userId).listen(
      (rooms) => enrichRooms(rooms),
      onError: (e) { if (!controller.isClosed) controller.addError(e); },
      onDone:  () { if (!controller.isClosed) controller.close(); },
    );

    return controller.stream;
  }

    // ── Presence (online status) ─────────────────────────────────────────
  // Single channel used for both tracking self and watching others.
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
    if (!_onlineController.isClosed) _onlineController.add(Set.from(_onlineIds));
  }

  void joinPresence(String userId, String userName) {
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
    try { _presenceChannel?.untrack(); } catch (_) {}
    if (_presenceChannel != null) {
      supabase.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
  }

  Stream<Set<String>> onlineUserIds() => onlineStream;

    Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    // SECURITY: enforce message length limit
    final safe = trimmed.length > _maxMessageLength
        ? trimmed.substring(0, _maxMessageLength)
        : trimmed;

    // SECURITY: verify the sender is actually a member of this room before
    // writing. Without this check, any authenticated user who knows a roomId
    // could inject messages into conversations they don't belong to.
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
      'last_message':      safe.length > 60 ? '${safe.substring(0, 60)}...' : safe,
      'last_message_time': now,
    }).eq('id', roomId);
  }
}
