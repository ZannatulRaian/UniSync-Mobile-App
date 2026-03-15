import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';

class EventCreationScreen extends ConsumerStatefulWidget {
  const EventCreationScreen({super.key});
  @override ConsumerState<EventCreationScreen> createState() => _EventCreationScreenState();
}

class _EventCreationScreenState extends ConsumerState<EventCreationScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _locCtrl   = TextEditingController();
  final _timeCtrl  = TextEditingController();
  String   _category = 'Academic';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  bool _loading = false;

  static const _cats = ['Academic','Tech','Cultural','Sports','Club','Other'];

  @override void dispose() {
    for (final c in [_titleCtrl,_descCtrl,_locCtrl,_timeCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    // SECURITY: verify role server-side is enforced by DB policy, but also
    // guard here so the screen cannot be misused if navigated directly
    if (user == null) return;
    if (user.role != 'faculty') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only faculty can create events'), backgroundColor: AppTheme.danger));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(eventServiceProvider).createEvent(
        title:       _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category:    _category,
        location:    _locCtrl.text.trim(),
        date:        _date,
        time:        _timeCtrl.text.trim(),
        organizer:   user.name,
        organizerId: user.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Event created!'), backgroundColor: AppTheme.accent));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text('New Event', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl('Title'), const SizedBox(height: 6),
          TextFormField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Event title'),
            validator: (v) => v!.trim().isNotEmpty ? null : 'Required'),
          const SizedBox(height: 16),
          _lbl('Category'), const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: _cats.map((c) => ChoiceChip(
            label: Text(c, style: GoogleFonts.inter(fontSize: 12)),
            selected: _category == c,
            selectedColor: AppTheme.primaryLight,
            onSelected: (_) => setState(() => _category = c),
          )).toList()),
          const SizedBox(height: 16),
          _lbl('Description'), const SizedBox(height: 6),
          TextFormField(controller: _descCtrl, maxLines: 4,
            decoration: const InputDecoration(hintText: 'Describe the event...'),
            validator: (v) => v!.trim().isNotEmpty ? null : 'Required'),
          const SizedBox(height: 16),
          _lbl('Location'), const SizedBox(height: 6),
          TextFormField(controller: _locCtrl,
            decoration: const InputDecoration(hintText: 'e.g. Main Auditorium',
              prefixIcon: Icon(Icons.location_on_outlined, size: 18, color: AppTheme.ink400)),
            validator: (v) => v!.trim().isNotEmpty ? null : 'Required'),
          const SizedBox(height: 16),
          _lbl('Date'), const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context, initialDate: _date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(color: AppTheme.surface, border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.ink400),
                const SizedBox(width: 10),
                Text(DateFormat('EEEE, MMMM d, yyyy').format(_date),
                  style: GoogleFonts.inter(color: AppTheme.ink900, fontSize: 14)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          _lbl('Time'), const SizedBox(height: 6),
          TextFormField(controller: _timeCtrl,
            decoration: const InputDecoration(hintText: 'e.g. 9:00 AM - 5:00 PM',
              prefixIcon: Icon(Icons.access_time_rounded, size: 18, color: AppTheme.ink400)),
            validator: (v) => v!.trim().isNotEmpty ? null : 'Required'),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create Event'),
          )),
        ])),
      ),
    );
  }

  Widget _lbl(String t) => Text(t, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink900));
}
