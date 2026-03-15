import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final ChatRoom room;
  const ChatRoomScreen({super.key, required this.room});
  @override ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _msgCtrl = TextEditingController();
  final _scroll  = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark room as read when opened AND refresh room list so badge clears
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final svc  = ref.read(chatServiceProvider);
      final user = ref.read(currentUserProvider);
      await svc.markRoomAsRead(widget.room.id);
      // Invalidate so the chat list re-fetches unread counts immediately
      if (user != null) {
        ref.invalidate(chatRoomsProvider(user.uid));
      }
    });
  }

  @override void dispose() { _msgCtrl.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    _msgCtrl.clear();
    try {
      await ref.read(chatServiceProvider).sendMessage(
        roomId: widget.room.id, senderId: user.uid, senderName: user.name, content: text,
      );
      // Scroll after a brief delay to let the stream deliver the new message
      Future.delayed(const Duration(milliseconds: 200), _scrollToBottom);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.room.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: AppTheme.primary,
        title: Builder(builder: (ctx) {
          final onlineIds = ref.watch(onlineUsersProvider).asData?.value ?? {};
          final me = ref.watch(currentUserProvider)?.uid ?? '';
          final otherIds = widget.room.memberIds.where((id) => id != me).toList();
          final isOnline = !widget.room.isGroup && otherIds.isNotEmpty && onlineIds.contains(otherIds.first);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.room.displayName(me), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            Row(children: [
              if (!widget.room.isGroup) ...[
                Container(width: 7, height: 7,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF4ADE80) : Colors.white38,
                    shape: BoxShape.circle,
                  )),
              ],
              Text(
                widget.room.isGroup
                    ? '${widget.room.memberIds.length} members'
                    : isOnline ? 'Online' : 'Offline',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
            ]),
          ]);
        })),
      body: Column(children: [
        Expanded(child: messagesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (messages) {
            // Scroll to bottom whenever message list updates
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            if (messages.isEmpty) return Center(child: Text('No messages yet. Say hi!', style: GoogleFonts.inter(color: AppTheme.ink400)));
            return ListView.builder(controller: _scroll, padding: const EdgeInsets.all(16),
              itemCount: messages.length, itemBuilder: (_, i) {
                final msg = messages[i];
                final isMe = msg.senderId == user?.uid;
                return _MessageBubble(msg: msg, isMe: isMe);
              });
          },
        )),
        // Input bar
        Container(decoration: const BoxDecoration(color: AppTheme.surface, border: Border(top: BorderSide(color: AppTheme.border))),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SafeArea(top: false, child: Row(children: [
            Expanded(child: TextField(controller: _msgCtrl,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink900),
              decoration: InputDecoration(hintText: 'Type a message...', hintStyle: GoogleFonts.inter(color: AppTheme.ink400, fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppTheme.primary)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), filled: true, fillColor: AppTheme.bg),
              onSubmitted: (_) => _send())),
            const SizedBox(width: 8),
            GestureDetector(onTap: _send, child: Container(width: 44, height: 44,
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
          ]))),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg; final bool isMe;
  const _MessageBubble({required this.msg, required this.isMe});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isMe) Padding(padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(msg.senderName, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink400, fontWeight: FontWeight.w600))),
        Container(constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            border: isMe ? null : Border.all(color: AppTheme.border),
          ),
          child: Text(msg.content, style: GoogleFonts.inter(fontSize: 14, color: isMe ? Colors.white : AppTheme.ink900))),
        Padding(padding: const EdgeInsets.only(top: 3, left: 8, right: 8),
          child: Text(DateFormat('h:mm a').format(msg.timestamp), style: GoogleFonts.inter(fontSize: 10, color: AppTheme.ink400))),
      ],
    ));
  }
}
