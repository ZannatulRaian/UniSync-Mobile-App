import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/announcement_model.dart';
import '../../services/announcement_service.dart';
import '../../widgets/shared_widgets.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});
  @override ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  String _type = 'All';
  static const _types = ['All','Academic','Financial','General','Club'];

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(currentUserProvider);
    final asyncList = ref.watch(announcementsStreamProvider(_type));
    final canPost   = user?.role == 'faculty';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text('Announcements', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (canPost)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
              onPressed: () => _showPostDialog(context),
            ),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(height: 38, child: ListView.builder(
            scrollDirection: Axis.horizontal, itemCount: _types.length,
            itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(right: 8),
              child: CategoryChip(
                label: _types[i], isSelected: _type == _types[i],
                onTap: () => setState(() => _type = _types[i]),
              ))))),
        Expanded(child: asyncList.when(
          loading: () => ListView.builder(itemCount: 4, itemBuilder: (_, __) => const ShimmerCard()),
          error:   (e, _) => AppError(message: 'Failed to load announcements'),
          data:    (list) {
            if (list.isEmpty) return const EmptyState(icon: Icons.campaign_outlined, title: 'No announcements', subtitle: 'Check back later');
            return ListView.builder(
              padding: const EdgeInsets.all(8), itemCount: list.length,
              itemBuilder: (_, i) => _AnnouncementTile(list[i]),
            );
          },
        )),
      ]),
    );
  }

  void _showPostDialog(BuildContext ctx) {
    final titleCtrl   = TextEditingController();
    final contentCtrl = TextEditingController();

    void disposeControllers() {
      titleCtrl.dispose();
      contentCtrl.dispose();
    }

    // SECURITY: double-check role before allowing post dialog to proceed
    final user = ref.read(currentUserProvider);
    if (user == null || (user.role != 'faculty')) return;

    String type = 'Academic';
    bool posting = false;

    showDialog(context: ctx, builder: (_) => StatefulBuilder(
      builder: (dCtx, setS) => AlertDialog(
        title: Text('Post Announcement', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: contentCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Content')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: type,
            items: ['Academic','Financial','General','Club']
                .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setS(() => type = v!),
          ),
        ])),
        actions: [
          TextButton(onPressed: () { disposeControllers(); Navigator.pop(dCtx); }, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: posting ? null : () async {
              if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Title and content are required')));
                return;
              }
              setS(() => posting = true);
              try {
                await ref.read(announcementServiceProvider).postAnnouncement(
                  title: titleCtrl.text.trim(), content: contentCtrl.text.trim(),
                  postedBy: user.name, postedById: user.id, type: type,
                );
                disposeControllers();
                if (dCtx.mounted) Navigator.pop(dCtx);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger));
                setS(() => posting = false);
              }
            },
            child: posting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Post'),
          ),
        ],
      ),
    ));
  }
}

class _AnnouncementTile extends ConsumerWidget {
  final Announcement a;
  const _AnnouncementTile(this.a);
  static const _colors = {
    'Academic': AppTheme.primary, 'Financial': AppTheme.accent,
    'General': AppTheme.warning,  'Club': Color(0xFF9B59B6),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c           = _colors[a.type] ?? AppTheme.ink400;
    final user        = ref.watch(currentUserProvider);
    final isBookmarked = user?.bookmarkedAnnouncements.contains(a.id) ?? false;
    final canDelete   = user?.role == 'faculty' || user?.id == a.postedById;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardOverlay, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(a.type, style: GoogleFonts.inter(color: c, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
          const Spacer(),
          Text(DateFormat('MMM d').format(a.postedAt), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink400)),
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              color: isBookmarked ? AppTheme.primary : AppTheme.ink400, size: 20,
            ),
            onPressed: user == null ? null : () async {
              await ref.read(announcementServiceProvider).bookmarkToggle(user.id, a.id, !isBookmarked);
              final newList = isBookmarked
                  ? ([...user.bookmarkedAnnouncements]..remove(a.id))
                  : [...user.bookmarkedAnnouncements, a.id];
              ref.read(authNotifierProvider.notifier).refreshUser(user.copyWith(bookmarkedAnnouncements: newList));
            },
          ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 20),
              onPressed: () async {
                await ref.read(announcementServiceProvider).deleteAnnouncement(a.id);
              },
            ),
        ]),
        const SizedBox(height: 8),
        Text(a.title,   style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.ink900)),
        const SizedBox(height: 6),
        Text(a.content, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.ink600, height: 1.5)),
        const SizedBox(height: 8),
        Text('Posted by ${a.postedBy}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink400)),
      ]),
    );
  }
}
