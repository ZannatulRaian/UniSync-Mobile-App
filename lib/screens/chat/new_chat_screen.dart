import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../services/profile_service.dart';
import 'chat_room_screen.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});
  @override ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _search    = TextEditingController();
  final _groupName = TextEditingController();
  // SECURITY: debounce prevents a query on every keystroke
  Timer? _debounce;
  bool _isGroup  = false;
  List<AppUser> _users    = [];
  List<AppUser> _selected = [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _groupName.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    // SECURITY: require at least 2 chars — prevents full-table scans
    if (q.trim().length < 2) {
      setState(() => _users = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _searchUsers(q));
  }

  Future<void> _searchUsers(String q) async {
    setState(() => _searching = true);
    try {
      final me = ref.read(currentUserProvider)?.id ?? '';
      // SECURITY: search goes through service layer which limits returned fields
      // and enforces minimum query length
      final results = await ProfileService().searchUsers(q, excludeId: me);
      if (mounted) setState(() => _users = results);
    } catch (_) {
      if (mounted) setState(() => _users = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _createChat() async {
    if (_selected.isEmpty) return;
    final me = ref.read(currentUserProvider);
    if (me == null) return;
    final memberIds   = [me.id, ..._selected.map((u) => u.id)];
    final memberNames = [me.name, ..._selected.map((u) => u.name)];
    final name = _isGroup ? _groupName.text.trim() : _selected.first.name;
    if (_isGroup && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter group name')));
      return;
    }
    final room = await ref.read(chatServiceProvider).createRoom(
      name: name, isGroup: _isGroup, memberIds: memberIds,
      memberNames: memberNames, createdById: me.id,
    );
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatRoomScreen(room: room)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: AppTheme.primary,
        title: Text('New Chat', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Row(children: [
            Text('Create group chat', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink900)),
            const Spacer(),
            Switch(value: _isGroup, onChanged: (v) => setState(() => _isGroup = v), activeColor: AppTheme.primary),
          ]),
          if (_isGroup) TextField(controller: _groupName, decoration: const InputDecoration(hintText: 'Group name', prefixIcon: Icon(Icons.group_rounded, size: 18, color: AppTheme.ink400))),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search by name (min 2 characters)...',
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppTheme.ink400)),
          ),
        ])),
        if (_selected.isNotEmpty) SizedBox(height: 56, child: ListView.builder(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _selected.length, itemBuilder: (_, i) {
            final u = _selected[i];
            return Padding(padding: const EdgeInsets.only(right: 8), child: Chip(
              label: Text(u.name, style: GoogleFonts.inter(fontSize: 12)),
              onDeleted: () => setState(() => _selected.remove(u)),
              deleteIconColor: AppTheme.danger,
            ));
          })),
        Expanded(child: _searching
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
            ? Center(child: Text(
                _search.text.trim().length < 2
                  ? 'Type at least 2 characters to search'
                  : 'No users found',
                style: GoogleFonts.inter(color: AppTheme.ink400, fontSize: 13)))
            : ListView.builder(itemCount: _users.length, itemBuilder: (_, i) {
                final u = _users[i];
                final sel = _selected.contains(u);
                return ListTile(
                  leading: CircleAvatar(backgroundColor: AppTheme.primaryLight,
                    child: Text(u.name[0], style: const TextStyle(color: AppTheme.primary))),
                  title: Text(u.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(u.department, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.ink400)),
                  trailing: Icon(sel ? Icons.check_circle_rounded : Icons.circle_outlined, color: sel ? AppTheme.accent : AppTheme.border),
                  onTap: () => setState(() => sel ? _selected.remove(u) : _selected.add(u)),
                );
              })),
        if (_selected.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity,
          child: ElevatedButton(onPressed: _createChat,
            child: Text(_isGroup ? 'Create Group' : 'Start Chat')))),
      ]),
    );
  }
}
