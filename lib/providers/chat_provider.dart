import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_service.dart';
import '../models/chat_model.dart';
import 'connectivity_provider.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return ChatService(db, connectivity);
});

// FIX: autoDispose prevents stale listeners stacking up across tab switches.
// family<> key is userId — when userId is empty string we return empty list
// so the UI never crashes while user is loading.
final chatRoomsProvider =
    StreamProvider.autoDispose.family<List<ChatRoom>, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value([]);
  return ref.watch(chatServiceProvider).getRoomsWithUnread(userId);
});

final chatMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, roomId) {
  if (roomId.isEmpty) return Stream.value([]);
  return ref.watch(chatServiceProvider).getMessages(roomId);
});

final onlineUsersProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  return ref.watch(chatServiceProvider).onlineUserIds();
});
