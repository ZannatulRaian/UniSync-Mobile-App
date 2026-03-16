import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/announcement_provider.dart';
import '../../models/event_model.dart';
import '../../models/announcement_model.dart';
import '../../models/resource_model.dart';
import '../../providers/resource_provider.dart';
import '../../widgets/shared_widgets.dart';
import '../events/events_list_screen.dart';
import '../events/event_detail_screen.dart';
import '../resources/resource_detail_screen.dart';
import '../resources/resources_screen.dart';
import 'announcements_screen.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final eventsAsync        = ref.watch(eventsStreamProvider);
    final announcementsAsync = ref.watch(announcementsStreamProvider('All'));
    final resourcesAsync     = ref.watch(resourcesStreamProvider(const ResourceFilter()));
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(backgroundColor: Colors.transparent, body: CustomScrollView(slivers: [
      // Header
      SliverToBoxAdapter(child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
        child: SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$greeting 👋', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
              Text(user?.name ?? 'Student', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              Text(user?.department ?? '', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
            ])),
            CircleAvatar(backgroundColor: Colors.white.withOpacity(0.15), child: const Icon(Icons.person_rounded, color: Colors.white, size: 24)),
          ]),
          const SizedBox(height: 16),
          // Quick stats
          Row(children: [
            if (user?.role == 'student') ...[
              _statBox('Semester', user?.semester?.isEmpty ?? true ? '-' : user!.semester),
              const SizedBox(width: 10),
            ] else ...[
              _statBox('Dept', user?.department != null && user!.department.length > 8
                ? '${user.department.substring(0,8)}..' : (user?.department ?? '-')),
              const SizedBox(width: 10),
            ],
            _statBox('ID', user?.studentId ?? '-'),
            const SizedBox(width: 10),
            _statBox('Role', (user?.role ?? 'Student').toUpperCase()),
          ]),
        ]))),
      )),
      // Announcements
      SliverToBoxAdapter(child: SectionHeader(title: 'Announcements', action: 'See all', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsScreen())))),
      SliverToBoxAdapter(child: announcementsAsync.when(
        loading: () => const ShimmerCard(),
        error: (e, _) => const SizedBox.shrink(),
        data: (list) => SizedBox(height: 100,
          child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.take(5).length, itemBuilder: (_, i) => _AnnouncementCard(list[i]))),
      )),
      // Upcoming events
      SliverToBoxAdapter(child: SectionHeader(title: 'Upcoming Events', action: 'See all', onAction: () {})),
      eventsAsync.when(
        loading: () => SliverList(delegate: SliverChildBuilderDelegate((_, i) => const ShimmerCard(), childCount: 3)),
        error: (e, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        data: (events) {
          final upcoming = events.where((e) => e.date.isAfter(DateTime.now())).take(4).toList();
          if (upcoming.isEmpty) return SliverToBoxAdapter(child: EmptyState(icon: Icons.event_rounded, title: 'No upcoming events', subtitle: 'Check back later'));
          return SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) => _EventCard(upcoming[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: upcoming[i])))),
            childCount: upcoming.length,
          ));
        },
      ),
      // Recent Resources
      SliverToBoxAdapter(child: SectionHeader(
        title: 'Recent Resources',
        action: 'See all',
        onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResourcesScreen())),
      )),
      SliverToBoxAdapter(child: resourcesAsync.when(
        loading: () => const ShimmerCard(),
        error:   (e, _) => const SizedBox.shrink(),
        data: (list) {
          final recent = list.take(4).toList();
          if (recent.isEmpty) return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('No resources yet. Upload one!',
              style: GoogleFonts.inter(color: AppTheme.ink400, fontSize: 13)),
          );
          return Column(
            children: recent.map((r) => _ResourceMiniTile(r)).toList(),
          );
        },
      )),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]));
  }

  Widget _statBox(String label, String value) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
      Text(label, style: GoogleFonts.inter(color: Colors.white60, fontSize: 10)),
    ]),
  ));
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement a;
  const _AnnouncementCard(this.a);
  static const _colors = {'Academic': AppTheme.primary, 'Financial': AppTheme.accent, 'General': AppTheme.warning, 'Club': Color(0xFF9B59B6)};
  @override
  Widget build(BuildContext context) {
    final color = _colors[a.type] ?? AppTheme.ink400;
    return Container(width: 220, margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0,2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(a.type, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color))),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 8),
          child: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink900)))),
        Text(a.postedBy, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink400)),
      ]),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  const _EventCard(this.event, {required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = Color(int.parse('FF${event.imageColor}', radix: 16));
    return GestureDetector(onTap: onTap, child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0,2))]),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.event_rounded, color: c, size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(event.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.ink900)),
          const SizedBox(height: 2),
          Text('${DateFormat('MMM d, yyyy').format(event.date)} • ${event.time}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.ink400)),
          Text('📍 ${event.location}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.ink600)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: AppTheme.ink400),
      ]),
    ));
  }
}

class _ResourceMiniTile extends StatelessWidget {
  final Resource r;
  const _ResourceMiniTile(this.r);

  @override
  Widget build(BuildContext context) {
    final c = Color(int.parse('FF${r.iconColor}', radix: 16));
    IconData icon = switch (r.type.toUpperCase()) {
      'PDF'            => Icons.picture_as_pdf_rounded,
      'DOCX' || 'DOC' => Icons.description_rounded,
      'PPT' || 'PPTX' => Icons.slideshow_rounded,
      _               => Icons.image_rounded,
    };
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => ResourceDetailScreen(resource: r))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0,2))],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: c.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: c, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink900),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${r.subject}  •  ${r.type}  •  ${r.size}',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink400)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(r.type,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.ink400, size: 18),
        ]),
      ),
    );
  }
}
