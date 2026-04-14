import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../services/profile_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    // FIX: Cache-bust the avatar URL so the updated photo loads immediately
    // after upload without requiring an app restart.
    final avatarUrl = (user.photoUrl != null && user.photoUrl!.isNotEmpty)
        ? Uri.parse(user.photoUrl!).replace(
            queryParameters: {'v': user.photoUrl.hashCode.toString()}).toString()
        : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text('Profile',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              ref.read(chatServiceProvider).leavePresence();
              ref.read(currentUserProvider.notifier).clear();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // ── Avatar ─────────────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              final img = await ImagePicker()
                  .pickImage(source: ImageSource.gallery, imageQuality: 70);
              if (img == null) return;
              try {
                await ProfileService().uploadProfilePhoto(user.uid, File(img.path));
                await ref.read(currentUserProvider.notifier).load(user.uid);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.toString().replaceAll('Exception: ', '')),
                  backgroundColor: AppTheme.danger,
                ));
              }
            },
            child: Stack(children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: AppTheme.primaryLight,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(user.name[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                            fontSize: 40, fontWeight: FontWeight.w700, color: AppTheme.primary))
                    : null,
              ),
              Positioned(bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                )),
            ]),
          ),
          const SizedBox(height: 14),
          Text(user.name,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.ink900)),
          Text(user.email,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.ink400)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(20)),
            child: Text(user.role.toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          ),
          const SizedBox(height: 24),

          // ── Info + bookmarks ────────────────────────────────────────────
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.94), borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _InfoCard(icon: Icons.school_rounded, label: 'Department', value: user.department),
              if (user.role == 'student')
                _InfoCard(icon: Icons.book_rounded, label: 'Semester',
                    value: user.semester.isEmpty ? 'Not set' : user.semester),
              _InfoCard(icon: Icons.badge_rounded, label: 'Student ID',
                  value: user.studentId.isEmpty ? 'Not set' : user.studentId),
              const SizedBox(height: 20),
              Text('Bookmarked Announcements',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.ink900)),
              const SizedBox(height: 10),
              if (user.bookmarkedAnnouncements.isEmpty)
                Text('No bookmarks yet',
                    style: GoogleFonts.inter(color: AppTheme.ink400, fontSize: 13))
              else
                Consumer(builder: (ctx, ref2, _) {
                  final ann = ref2.watch(announcementsStreamProvider(null));
                  return ann.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                    data: (list) {
                      final bookmarked = list
                          .where((a) => user.bookmarkedAnnouncements.contains(a.id))
                          .toList();
                      return Column(children: bookmarked.map((a) => ListTile(
                        dense: true, contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bookmark_rounded, color: AppTheme.primary, size: 18),
                        title: Text(a.title,
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink900)),
                        subtitle: Text(a.type,
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink400)),
                      )).toList());
                    },
                  );
                }),
            ]),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _InfoCard({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border)),
    child: Row(children: [
      Icon(icon, size: 18, color: AppTheme.primary),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink400)),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.ink900)),
      ]),
    ]),
  );
}
