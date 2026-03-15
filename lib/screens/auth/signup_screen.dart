import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../dashboard/main_dashboard.dart';
import 'login_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final String preselectedRole;
  final String prefilledId;

  const SignupScreen({
    super.key,
    required this.preselectedRole,
    required this.prefilledId,
  });

  @override ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _dept      = 'Computer Science';
  String _semester  = '1st';
  bool   _loading   = false;
  bool   _obscure   = true;
  bool   _obscureC  = true;

  static const _depts = ['Computer Science','Mathematics','Physics','EEE','Business','English','Other'];
  static const _sems  = ['1st','2nd','3rd','4th','5th','6th','7th','8th'];

  bool get _isFaculty => widget.preselectedRole == 'faculty';

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _passCtrl, _confirmCtrl]) c.dispose();
    super.dispose();
  }



  Future<void> _pickDepartment(BuildContext ctx) async {
    final picked = await showModalBottomSheet<String>(
      context: ctx,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Text('Select Department', style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.ink900)),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, color: AppTheme.ink400, size: 20)),
          ]),
        ),
        const Divider(height: 1),
        ..._depts.map((d) => ListTile(
          title: Text(d, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink900)),
          trailing: _dept == d
              ? const Icon(Icons.check_rounded, color: AppTheme.primary, size: 20)
              : null,
          onTap: () => Navigator.pop(ctx, d),
        )),
        const SizedBox(height: 16),
      ]),
    );
    if (picked != null) setState(() => _dept = picked);
  }

  Future<void> _pickSemester(BuildContext ctx) async {
    final picked = await showModalBottomSheet<String>(
      context: ctx,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Text('Select Semester', style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.ink900)),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, color: AppTheme.ink400, size: 20)),
          ]),
        ),
        const Divider(height: 1),
        ..._sems.map((s) => ListTile(
          title: Text(s, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink900)),
          trailing: _semester == s
              ? const Icon(Icons.check_rounded, color: AppTheme.primary, size: 20)
              : null,
          onTap: () => Navigator.pop(ctx, s),
        )),
        const SizedBox(height: 16),
      ]),
    );
    if (picked != null) setState(() => _semester = picked);
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await ref.read(authServiceProvider).signUp(
        name:       _nameCtrl.text.trim(),
        email:      _emailCtrl.text.trim(),
        password:   _passCtrl.text,
        department: _dept,
        semester:   _isFaculty ? '' : _semester,
        studentId:  widget.prefilledId,
        // Role is derived server-side from the ID format — no need to send it
      );
      ref.read(authNotifierProvider.notifier).update(user);
      if (!mounted) return;
      // Clear entire navigation stack so back button can't return to signup/onboarding
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyAuthError(e)),
        backgroundColor: AppTheme.danger,
      ));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _isFaculty ? AppTheme.accent : AppTheme.primary;
    final roleLabel = _isFaculty ? 'Faculty' : 'Student';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.ink900)),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Create account', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.ink900)),
          Text('Join UniSync today', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink400)),
          const SizedBox(height: 16),

          // Role badge — locked, set from onboarding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: roleColor.withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(_isFaculty ? Icons.person_4_outlined : Icons.school_outlined, size: 18, color: roleColor),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Role: $roleLabel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: roleColor)),
                Text('ID: ${widget.prefilledId}', style: GoogleFonts.inter(fontSize: 12, color: roleColor.withOpacity(0.8))),
              ]),
              const Spacer(),
              const Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.ink400),
            ]),
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline, size: 18)),
            validator: (v) => v!.trim().isNotEmpty ? null : 'Name is required',
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'University Email',
              hintText: 'e.g. zraian@daffodilvarsity.edu.bd',
              prefixIcon: Icon(Icons.email_outlined, size: 18),
            ),
            validator: (v) {
              if (v!.isEmpty) return 'Email is required';
              final email = v.trim().toLowerCase();
              if (!email.contains('@') || !email.contains('.')) return 'Enter a valid email';
              if (!email.endsWith('.edu') && !email.endsWith('.edu.bd') && !email.endsWith('.ac.bd') && !email.endsWith('.ac.uk') && !email.endsWith('.ac.in')) return 'Must be a university email (e.g. .edu, .edu.bd, .ac.bd)';
              final parts = email.split('@');
              if (parts.length != 2 || parts[0].isEmpty || parts[1].length < 5) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password (min 8 characters)',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => v!.length >= 8 ? null : 'Password must be at least 8 characters',
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscureC,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_obscureC ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                onPressed: () => setState(() => _obscureC = !_obscureC),
              ),
            ),
            validator: (v) => v == _passCtrl.text ? null : 'Passwords do not match',
          ),
          const SizedBox(height: 14),

          GestureDetector(
            onTap: () => _pickDepartment(context),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Department',
                prefixIcon: Icon(Icons.school_outlined, size: 18),
                suffixIcon: Icon(Icons.expand_more_rounded, size: 20),
              ),
              child: Text(_dept, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink900)),
            ),
          ),

          // Semester only for students — uses bottom sheet to avoid dropdown overlay shadow
          if (!_isFaculty) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _pickSemester(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Semester',
                  prefixIcon: Icon(Icons.format_list_numbered_outlined, size: 18),
                  suffixIcon: Icon(Icons.expand_more_rounded, size: 20),
                ),
                child: Text(_semester, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.ink900)),
              ),
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _loading ? null : _signup,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create Account'),
          )),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Already have an account? ', style: GoogleFonts.inter(color: AppTheme.ink600, fontSize: 14)),
            GestureDetector(
              onTap: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              ),
              child: Text('Sign in', style: GoogleFonts.inter(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ]),
          const SizedBox(height: 20),
        ])),
      )),
    );
  }
}
