import 'package:isar/isar.dart';
import 'chat_model.dart';

part 'isar_chat.g.dart';

@collection
class IsarChatRoom {
  Id? id = Isar.autoIncrement;
  
  late String remoteId;
  late String name;
  late String lastMessage;
  late DateTime lastMessageTime;
  late bool isGroup;
  late List<String> memberIds;
  late List<String> memberNames;
  late List<String?> memberPhotoUrls;
  late String avatarColor;
  late int unreadCount;
  late DateTime cachedAt;
  late bool isDeleted;
  
  IsarChatRoom({
    this.id,
    required this.remoteId,
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isGroup,
    required this.memberIds,
    required this.memberNames,
    required this.memberPhotoUrls,
    required this.avatarColor,
    this.unreadCount = 0,
    required this.cachedAt,
    this.isDeleted = false,
  });

  factory IsarChatRoom.fromChatRoom(ChatRoom r, {List<String?>? photoUrls}) => IsarChatRoom(
    remoteId: r.id,
    name: r.name,
    lastMessage: r.lastMessage,
    lastMessageTime: r.lastMessageTime,
    isGroup: r.isGroup,
    memberIds: r.memberIds,
    memberNames: r.memberNames,
    memberPhotoUrls: photoUrls ?? r.memberPhotoUrls,
    avatarColor: r.avatarColor,
    unreadCount: r.unreadCount,
    cachedAt: DateTime.now(),
  );

  ChatRoom toChatRoom() => ChatRoom(
    id: remoteId,
    name: name,
    lastMessage: lastMessage,
    lastMessageTime: lastMessageTime,
    isGroup: isGroup,
    memberIds: memberIds,
    memberNames: memberNames,
    memberPhotoUrls: memberPhotoUrls,
    avatarColor: avatarColor,
    unreadCount: unreadCount,
  );

  Map<String, dynamic> toMap() => {
    'id': remoteId,
    'name': name,
    'last_message': lastMessage,
    'last_message_time': lastMessageTime.toIso8601String(),
    'is_group': isGroup,
    'member_ids': memberIds,
    'member_names': memberNames,
    'avatar_color': avatarColor,
  };
}

@collection
class IsarChatMessage {
  Id? id = Isar.autoIncrement;
  
  late String remoteId;
  late String roomId;
  late String senderId;
  late String senderName;
  late String content;
  late DateTime timestamp;
  late DateTime cachedAt;
  late bool isDeleted;
  
  IsarChatMessage({
    this.id,
    required this.remoteId,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.cachedAt,
    this.isDeleted = false,
  });

  factory IsarChatMessage.fromChatMessage(ChatMessage m) => IsarChatMessage(
    remoteId: m.id,
    roomId: m.roomId,
    senderId: m.senderId,
    senderName: m.senderName,
    content: m.content,
    timestamp: m.timestamp,
    cachedAt: DateTime.now(),
  );

  ChatMessage toChatMessage() => ChatMessage(
    id: remoteId,
    roomId: roomId,
    senderId: senderId,
    senderName: senderName,
    content: content,
    timestamp: timestamp,
  );

  Map<String, dynamic> toMap() => {
    'id': remoteId,
    'room_id': roomId,
    'sender_id': senderId,
    'sender_name': senderName,
    'content': content,
    'created_at': timestamp.toIso8601String(),
  };
}
