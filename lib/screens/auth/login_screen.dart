import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/auth_service.dart';
import '../dashboard/main_dashboard.dart';
import '../onboarding/onboarding_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await ref.read(authServiceProvider).signIn(_emailCtrl.text.trim(), _passCtrl.text);
      ref.read(currentUserProvider.notifier).update(user);
      ref.read(chatServiceProvider).joinPresence(user.uid, user.name);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainDashboard()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyAuthError(e)),
        backgroundColor: AppTheme.danger,
      ));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your email first')));
      return;
    }
    if (!email.contains('@') || (!email.endsWith('.edu') && !email.endsWith('.edu.bd') && !email.endsWith('.ac.bd') && !email.endsWith('.ac.uk') && !email.endsWith('.ac.in'))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Must be a university email (e.g. .edu, .edu.bd, .ac.bd)')));
      return;
    }
    await ref.read(authServiceProvider).sendPasswordReset(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 40),
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0,3))],
          ),
          padding: const EdgeInsets.all(10),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 32),
        Text('Welcome back', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.ink900)),
        const SizedBox(height: 4),
        Text('Welcome back to UniSync', style: GoogleFonts.inter(fontSize: 15, color: AppTheme.ink400)),
        const SizedBox(height: 36),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
              labelText: 'University Email',
              hintText: 'e.g. zraian@daffodilvarsity.edu.bd',
              prefixIcon: Icon(Icons.email_outlined, size: 18),
            ),
          validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              final email = v.trim().toLowerCase();
              if (!email.contains('@') || (!email.endsWith('.edu') && !email.endsWith('.edu.bd') && !email.endsWith('.ac.bd') && !email.endsWith('.ac.uk') && !email.endsWith('.ac.in'))) return 'Must be a university email (e.g. .edu, .edu.bd, .ac.bd)';
              return null;
            },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline, size: 18),
            suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18), onPressed: () => setState(() => _obscure = !_obscure)),
          ),
          validator: (v) => v!.length >= 8 ? null : 'Password must be at least 8 characters',
        ),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _resetPassword, child: Text('Forgot password?', style: GoogleFonts.inter(color: AppTheme.primary, fontSize: 13)))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _loading ? null : _login,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Sign In'),
        )),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("Don't have an account? ", style: GoogleFonts.inter(color: AppTheme.ink600, fontSize: 14)),
          GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OnboardingScreen(onDone: () => Navigator.pop(context)))),
            child: Text('Sign up', style: GoogleFonts.inter(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 14))),
        ]),
      ])))),
    );
  }
}
