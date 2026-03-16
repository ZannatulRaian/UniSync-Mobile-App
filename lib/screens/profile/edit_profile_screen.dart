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

  Future<void> _pickDept() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(children: [
            Text('Select Department',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.ink900)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: AppTheme.ink400, size: 20)),
          ]),
        ),
        const Divider(height: 1),
        ..._depts.map((d) => ListTile(
          tileColor: Colors.white,
          title: Text(d, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink900)),
          trailing: _dept == d
              ? const Icon(Icons.check_rounded, color: AppTheme.primary, size: 20) : null,
          onTap: () => Navigator.pop(context, d),
        )),
        const SizedBox(height: 16),
      ]),
    );
    if (picked != null) setState(() => _dept = picked);
  }

  Future<void> _pickSemester() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(children: [
            Text('Select Semester',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.ink900)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: AppTheme.ink400, size: 20)),
          ]),
        ),
        const Divider(height: 1),
        ..._sems.map((s) => ListTile(
          tileColor: Colors.white,
          title: Text(s, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink900)),
          trailing: _semester == s
              ? const Icon(Icons.check_rounded, color: AppTheme.primary, size: 20) : null,
          onTap: () => Navigator.pop(context, s),
        )),
        const SizedBox(height: 16),
      ]),
    );
    if (picked != null) setState(() => _semester = picked);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final u = ref.read(currentUserProvider);
    if (u == null) { setState(() => _loading = false); return; }
    try {
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
  Widget build(BuildContext context) {
    final isFaculty = ref.read(currentUserProvider)?.role == 'faculty';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text('Edit Profile',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07),
              blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name field
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline, size: 18)),
            ),
            const SizedBox(height: 16),

            // Department picker
            GestureDetector(
              onTap: _pickDept,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.school_outlined, size: 18),
                  suffixIcon: Icon(Icons.expand_more_rounded, size: 20),
                ),
                child: Text(_dept,
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink900)),
              ),
            ),
            const SizedBox(height: 16),

            // Semester picker (students only)
            if (!isFaculty) ...[
              GestureDetector(
                onTap: _pickSemester,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Semester',
                    prefixIcon: Icon(Icons.format_list_numbered_outlined, size: 18),
                    suffixIcon: Icon(Icons.expand_more_rounded, size: 20),
                  ),
                  child: Text(_semester,
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink900)),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            )),
          ]),
        ),
      ),
    );
  }
}
