import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  String _dept     = 'Computer Science';
  String _semester = '6th';
  bool   _loading  = false;

  static const _depts = ['Computer Science','Mathematics','Physics','EEE','Business','English','Other'];
  static const _sems  = ['1st','2nd','3rd','4th','5th','6th','7th','8th'];

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentUserProvider);
    if (u != null) {
      _nameCtrl.text = u.name;
      _dept     = _depts.contains(u.department) ? u.department : 'Computer Science';
      _semester = _sems.contains(u.semester)    ? u.semester   : '6th';
    }
  }

  @override void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _loading = true);
    final u = ref.read(currentUserProvider);
    if (u == null) { setState(() => _loading = false); return; }
    try {
      // FIX: use named parameters, not a positional Map
      await ref.read(authServiceProvider).updateUser(
        u.id,
        name:       _nameCtrl.text.trim(),
        department: _dept,
        semester:   _semester,
      );
      await ref.read(currentUserProvider.notifier).load(u.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      backgroundColor: AppTheme.primary,
      title: Text('Edit Profile',
        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFormField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person_outline, size: 18)),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _dept, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Department'),
          items: _depts.map((d) => DropdownMenuItem(
            value: d, child: Text(d, style: GoogleFonts.inter(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _dept = v!),
        ),
        const SizedBox(height: 16),
        if (ref.read(currentUserProvider)?.role != 'faculty')
        DropdownButtonFormField<String>(
          value: _semester, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Semester'),
          items: _sems.map((s) => DropdownMenuItem(
            value: s, child: Text(s, style: GoogleFonts.inter(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _semester = v!),
        ),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save Changes'),
        )),
      ]),
    ),
  );
}
