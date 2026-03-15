import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../theme/app_theme.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/event_model.dart';
import '../../widgets/shared_widgets.dart';
import 'event_detail_screen.dart';
import 'event_creation_screen.dart';

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});
  @override ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _category = 'All';
  String _search = '';
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  static const _cats = ['All','Tech','Cultural','Academic','Sports','Club','Other'];

  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.primary, title: Text('Events', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (user?.role == 'faculty')
            IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventCreationScreen()))),
        ],
        bottom: TabBar(controller: _tab, indicatorColor: AppTheme.warning, indicatorWeight: 3,
          labelColor: Colors.white, unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [Tab(text: 'List View'), Tab(text: 'Calendar')]),
      ),
      body: TabBarView(controller: _tab, children: [_buildList(), _buildCalendar()]),
    );
  }

  Widget _buildList() {
    return ref.watch(eventsStreamProvider).when(
      loading: () => ListView.builder(itemCount: 4, itemBuilder: (_, __) => const ShimmerCard(height: 90)),
      error: (e, _) => AppError(message: 'Failed to load events', onRetry: () => ref.invalidate(eventsStreamProvider)),
      data: (events) {
        var filtered = events.where((e) {
          if (_category != 'All' && e.category != _category) return false;
          if (_search.isNotEmpty && !e.title.toLowerCase().contains(_search.toLowerCase())) return false;
          return true;
        }).toList();
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,12,16,8),
            child: AppSearchBar(hint: 'Search events...', onChanged: (v) => setState(() => _search = v)))),
          SliverToBoxAdapter(child: SizedBox(height: 44, child: ListView.builder(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _cats.length, itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(right: 8),
              child: CategoryChip(label: _cats[i], isSelected: _category == _cats[i], onTap: () => setState(() => _category = _cats[i])))))),
          if (filtered.isEmpty) const SliverFillRemaining(child: EmptyState(icon: Icons.event_outlined, title: 'No events found', subtitle: 'Try a different category or search'))
          else SliverList(delegate: SliverChildBuilderDelegate((_, i) => _EventTile(filtered[i]), childCount: filtered.length)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ]);
      },
    );
  }

  Widget _buildCalendar() {
    return ref.watch(eventsStreamProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppError(message: 'Failed to load events'),
      data: (events) {
        final eventMap = <DateTime, List<Event>>{};
        for (final e in events) {
          final day = DateTime(e.date.year, e.date.month, e.date.day);
          eventMap.putIfAbsent(day, () => []).add(e);
        }
        final dayEvents = _selectedDay != null ? (eventMap[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)] ?? []) : [];
        return Column(children: [
          TableCalendar<Event>(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay, selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            eventLoader: (day) => eventMap[DateTime(day.year, day.month, day.day)] ?? [],
            onDaySelected: (sel, foc) => setState(() { _selectedDay = sel; _focusedDay = foc; }),
            headerStyle: HeaderStyle(formatButtonVisible: false, titleCentered: true,
              titleTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
              todayTextStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
              selectedDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              markerDecoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
            ),
          ),
          if (dayEvents.isNotEmpty) Expanded(child: ListView.builder(padding: const EdgeInsets.all(16),
            itemCount: dayEvents.length, itemBuilder: (_, i) => _EventTile(dayEvents[i]))),
        ]);
      },
    );
  }
}

class _EventTile extends ConsumerWidget {
  final Event event;
  const _EventTile(this.event);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Color(int.parse('FF${event.imageColor}', radix: 16));
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: event))),
      child: Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.cardOverlay, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(0.2))),
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(DateFormat('MMM').format(event.date), style: GoogleFonts.inter(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
              Text(DateFormat('d').format(event.date), style: GoogleFonts.poppins(fontSize: 18, color: c, fontWeight: FontWeight.w700)),
            ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(event.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.ink900))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(event.category, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: c))),
            ]),
            const SizedBox(height: 4),
            Text('${event.time}  •  📍${event.location}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.ink400)),
            const SizedBox(height: 2),
            Text('${event.attendees} going • ${event.organizer}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.ink600)),
          ])),
        ]),
      ),
    );
  }
}
