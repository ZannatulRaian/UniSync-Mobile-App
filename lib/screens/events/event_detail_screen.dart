import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../services/event_service.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final Event event;
  const EventDetailScreen({super.key, required this.event});
  @override ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  late bool _rsvped;
  bool _loading = false;

  @override void initState() { super.initState(); _rsvped = widget.event.isRSVPed; }

  Future<void> _toggleRsvp() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(eventServiceProvider).rsvpEvent(widget.event.id, user.uid, !_rsvped);
      setState(() { _rsvped = !_rsvped; });
    } finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final c = Color(int.parse('FF${e.imageColor}', radix: 16));
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(slivers: [
        SliverAppBar(expandedHeight: 180, pinned: true, backgroundColor: c,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c, c.withOpacity(0.7)])),
              child: Center(child: Icon(Icons.event_rounded, size: 72, color: Colors.white.withOpacity(0.3)))),
            title: Text(e.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
          )),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Category + attendees
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(e.category, style: GoogleFonts.inter(color: c, fontWeight: FontWeight.w600, fontSize: 13))),
            const Spacer(),
            Icon(Icons.people_rounded, size: 16, color: AppTheme.ink400),
            const SizedBox(width: 4),
            Text('${e.attendees} attending', style: GoogleFonts.inter(color: AppTheme.ink600, fontSize: 13)),
          ]),
          const SizedBox(height: 20),
          _infoRow(Icons.calendar_today_rounded, DateFormat('EEEE, MMMM d, yyyy').format(e.date), c),
          const SizedBox(height: 12),
          _infoRow(Icons.access_time_rounded, e.time, c),
          const SizedBox(height: 12),
          _infoRow(Icons.location_on_rounded, e.location, c),
          const SizedBox(height: 12),
          _infoRow(Icons.person_rounded, e.organizer, c),
          const SizedBox(height: 24),
          Text('About this event', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.ink900)),
          const SizedBox(height: 8),
          Text(e.description, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink600, height: 1.6)),
          const SizedBox(height: 32),
          // RSVP button
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _loading ? null : _toggleRsvp,
            style: ElevatedButton.styleFrom(backgroundColor: _rsvped ? AppTheme.accent : c),
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_rsvped ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, size: 18),
            label: Text(_rsvped ? "You're going! (Tap to cancel)" : 'RSVP — I\'m going',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
          )),
          // Delete button for organizer or faculty
          if (user?.uid == e.organizerId || user?.role == 'faculty') ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(eventServiceProvider).deleteEvent(e.id);
                if (context.mounted) Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.danger)),
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 18),
              label: Text('Delete Event', style: GoogleFonts.inter(color: AppTheme.danger, fontWeight: FontWeight.w600)),
            )),
          ],
        ]))),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String text, Color c) => Row(children: [
    Container(width: 36, height: 36, decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 18, color: c)),
    const SizedBox(width: 12),
    Expanded(child: Text(text, style: GoogleFonts.inter(color: AppTheme.ink900, fontSize: 14))),
  ]);
}
