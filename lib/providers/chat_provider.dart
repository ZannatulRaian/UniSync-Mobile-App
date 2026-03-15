import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_service.dart';
import '../models/chat_model.dart';

final chatServiceProvider = Provider((_) => ChatService());

final chatRoomsProvider = StreamProvider.family<List<ChatRoom>, String>((ref, userId) =>
    ref.watch(chatServiceProvider).getRoomsWithUnread(userId));

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, roomId) =>
    ref.watch(chatServiceProvider).getMessages(roomId));

final onlineUsersProvider = StreamProvider<Set<String>>((ref) =>
    ref.watch(chatServiceProvider).onlineUserIds());
