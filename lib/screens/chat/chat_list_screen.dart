import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat_model.dart';
import '../../widgets/shared_widgets.dart';
import 'chat_room_screen.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());
    final roomsAsync  = ref.watch(chatRoomsProvider(user.uid));
    final onlineAsync = ref.watch(onlineUsersProvider);
    final onlineIds   = onlineAsync.asData?.value ?? {};

    // Join presence whenever this screen is visible
    ref.listen(currentUserProvider, (_, u) {
      if (u != null) ref.read(chatServiceProvider).joinPresence(u.uid, u.name);
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text('Messages', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatScreen())),
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      body: roomsAsync.when(
        loading: () => ListView.builder(itemCount: 5, itemBuilder: (_, __) => const ShimmerCard()),
        error:   (e, _) => AppError(message: 'Failed to load chats'),
        data: (rooms) {
          if (rooms.isEmpty) return EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No conversations yet',
            subtitle: 'Start a new chat',
            action: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatScreen())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Chat'),
            ),
          );

          return Column(children: [
            // ── Story-style active users bar ────────────────────────
            _ActiveUsersBar(rooms: rooms, currentUserId: user.uid, onlineIds: onlineIds),
            const Divider(height: 1),
            // ── Chat list ────────────────────────────────────────────
            Expanded(child: ListView.separated(
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) => _RoomTile(rooms[i], user.uid, onlineIds),
            )),
          ]);
        },
      ),
    );
  }
}

// ── Active users story bar (Instagram/WhatsApp style) ─────────────────────────
class _ActiveUsersBar extends StatelessWidget {
  final List<ChatRoom> rooms;
  final String currentUserId;
  final Set<String> onlineIds;

  const _ActiveUsersBar({
    required this.rooms,
    required this.currentUserId,
    required this.onlineIds,
  });

  @override
  Widget build(BuildContext context) {
    // Only show DM rooms; extract the "other" person from each
    final dmRooms = rooms.where((r) => !r.isGroup).toList();
    if (dmRooms.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: dmRooms.length,
        itemBuilder: (_, i) {
          final room = dmRooms[i];
          final otherIds = room.memberIds.where((id) => id != currentUserId).toList();
          final isOnline = otherIds.isNotEmpty && onlineIds.contains(otherIds.first);
          final color = Color(int.parse('FF${room.avatarColor}', radix: 16));
          final displayName = room.displayName(currentUserId);
          final initial = room.displayInitial(currentUserId);
          // Short display name (first word only)
          final shortName = displayName.split(' ').first;

          return GestureDetector(
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ChatRoomScreen(room: room))),
            child: Container(
              width: 68,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(clipBehavior: Clip.none, children: [
                    // Glowing ring when online
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isOnline ? AppTheme.accent : AppTheme.border,
                          width: isOnline ? 2.5 : 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: CircleAvatar(
                          backgroundColor: color.withOpacity(0.15),
                          child: Text(initial,
                            style: GoogleFonts.poppins(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            )),
                        ),
                      ),
                    ),
                    // Online green dot
                    if (isOnline)
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 13, height: 13,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    shortName,
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink900, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Chat room tile ─────────────────────────────────────────────────────────────
class _RoomTile extends StatelessWidget {
  final ChatRoom room;
  final String userId;
  final Set<String> onlineIds;
  const _RoomTile(this.room, this.userId, this.onlineIds);

  @override
  Widget build(BuildContext context) {
    final c = Color(int.parse('FF${room.avatarColor}', radix: 16));
    final otherIds = room.memberIds.where((id) => id != userId).toList();
    final isOnline = !room.isGroup && otherIds.isNotEmpty && onlineIds.contains(otherIds.first);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatRoomScreen(room: room))),
      leading: Stack(clipBehavior: Clip.none, children: [
        CircleAvatar(
          backgroundColor: c.withOpacity(0.15),
          child: Text(room.displayInitial(userId),
            style: GoogleFonts.poppins(color: c, fontWeight: FontWeight.w700))),
        if (isOnline)
          Positioned(bottom: 0, right: 0,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ))),
      ]),
      title: Row(children: [
        Expanded(child: Text(room.displayName(userId),
          style: GoogleFonts.poppins(
            fontWeight: room.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
            color: room.unreadCount > 0 ? AppTheme.ink900 : AppTheme.ink600,
          ))),
        if (isOnline) ...[
          const SizedBox(width: 6),
          Text('Online', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.w600)),
        ],
      ]),
      subtitle: Text(room.lastMessage,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: room.unreadCount > 0 ? AppTheme.ink600 : AppTheme.ink400,
          fontWeight: room.unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
        ),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(timeago.format(room.lastMessageTime),
          style: GoogleFonts.inter(
            fontSize: 10,
            color: room.unreadCount > 0 ? AppTheme.primary : AppTheme.ink400,
            fontWeight: room.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
          )),
        if (room.unreadCount > 0) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
            child: Text('${room.unreadCount}',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center)),
        ],
      ]),
      ),
    );
  }
}
