import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_service.dart';
import '../models/chat_model.dart';
import 'connectivity_provider.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return ChatService(db, connectivity);
});

// autoDispose ensures the stream is cancelled when leaving the chat tab,
// preventing stale listeners from stacking up and causing duplicate rooms.
final chatRoomsProvider =
    StreamProvider.autoDispose.family<List<ChatRoom>, String>((ref, userId) {
  return ref.watch(chatServiceProvider).getRoomsWithUnread(userId);
});

final chatMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, roomId) {
  return ref.watch(chatServiceProvider).getMessages(roomId);
});

final onlineUsersProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  return ref.watch(chatServiceProvider).onlineUserIds();
});
