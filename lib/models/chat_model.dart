class ChatRoom {
  final String id;
  final String name;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isGroup;
  final List<String> memberIds;
  final List<String> memberNames;

  // FIX: stores each member's photo URL (parallel to memberIds/memberNames).
  // Populated at runtime by ChatService — not stored in the DB, so it's
  // always up-to-date even after a member changes their profile picture.
  final List<String?> memberPhotoUrls;

  final String avatarColor;
  int unreadCount;

  ChatRoom({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isGroup,
    required this.memberIds,
    required this.memberNames,
    List<String?>? memberPhotoUrls,
    required this.avatarColor,
    this.unreadCount = 0,
  }) : memberPhotoUrls = memberPhotoUrls ?? [];

  factory ChatRoom.fromMap(Map<String, dynamic> d) => ChatRoom(
    id:              d['id'],
    name:            d['name'] ?? '',
    lastMessage:     d['last_message'] ?? '',
    lastMessageTime: DateTime.parse(
        d['last_message_time'] ?? DateTime.now().toIso8601String()),
    isGroup:         d['is_group'] ?? false,
    memberIds:       List<String>.from(d['member_ids'] ?? []),
    memberNames:     List<String>.from(d['member_names'] ?? []),
    // memberPhotoUrls is not in DB — populated separately by ChatService
    memberPhotoUrls: [],
    avatarColor:     d['avatar_color'] ?? '1A56DB',
  );

  /// For DMs returns the OTHER person's name; for groups returns the group name.
  String displayName(String currentUserId) {
    if (isGroup) return name;
    final idx = memberIds.indexOf(currentUserId);
    if (idx == -1) return name;
    for (var i = 0; i < memberNames.length; i++) {
      if (i != idx) return memberNames[i];
    }
    return name;
  }

  /// For DMs returns the first letter of the OTHER person's name.
  String displayInitial(String currentUserId) {
    final n = displayName(currentUserId);
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  /// Returns the OTHER person's photo URL for DMs, null for groups.
  String? displayPhotoUrl(String currentUserId) {
    if (isGroup || memberPhotoUrls.isEmpty) return null;
    final idx = memberIds.indexOf(currentUserId);
    if (idx == -1) return null;
    for (var i = 0; i < memberPhotoUrls.length; i++) {
      if (i != idx) return memberPhotoUrls[i];
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'last_message': lastMessage,
    'last_message_time': lastMessageTime.toIso8601String(),
    'is_group': isGroup, 'member_ids': memberIds,
    'member_names': memberNames, 'avatar_color': avatarColor,
  };
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id, required this.roomId, required this.senderId,
    required this.senderName, required this.content, required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> d) => ChatMessage(
    id:         d['id'],
    roomId:     d['room_id'] ?? '',
    senderId:   d['sender_id'] ?? '',
    senderName: d['sender_name'] ?? '',
    content:    d['content'] ?? '',
    timestamp:  DateTime.parse(d['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'room_id': roomId, 'sender_id': senderId,
    'sender_name': senderName, 'content': content,
    'created_at': timestamp.toIso8601String(),
  };
}