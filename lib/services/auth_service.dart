import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_client.dart';

class AuthService {
  User? get currentUser => supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
    required String department,
    required String semester,
    required String studentId,
  }) async {
    // SECURITY: role is NOT accepted from client — DB trigger forces 'student'
    // Validate inputs before sending to server
    if (name.trim().isEmpty) throw Exception('Name cannot be empty');
    if (password.length < 8)  throw Exception('Password must be at least 8 characters');

    final res = await supabase.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {'name': name.trim()},
    );
    if (res.user == null) throw Exception('Sign up failed. Please try again.');
    final uid = res.user!.id;

    await supabase.from('users').insert({
      'id':         uid,
      'name':       name.trim(),
      'email':      email.trim().toLowerCase(),
      'department': department,
      'semester':   semester,
      'student_id': studentId.trim(),
      // role NOT included — DB trigger sets it to 'student' automatically
    });

    return getUser(uid);
  }

  Future<AppUser> signIn(String email, String password) async {
    final e = email.trim().toLowerCase();
    final validDomains = ['.edu', '.edu.bd', '.ac.bd', '.ac.uk', '.ac.in'];
    if (!validDomains.any((d) => e.endsWith(d))) throw Exception('Must be a university email (e.g. .edu, .edu.bd, .ac.bd)');
    final res = await supabase.auth.signInWithPassword(
      email: e,
      password: password,
    );
    if (res.user == null) throw Exception('Login failed. Check your email and password.');
    return getUser(res.user!.id);
  }

  Future<void> signOut() => supabase.auth.signOut();

  Future<void> sendPasswordReset(String email) {
    final e = email.trim().toLowerCase();
    final validDomains = ['.edu', '.edu.bd', '.ac.bd', '.ac.uk', '.ac.in'];
    if (!validDomains.any((d) => e.endsWith(d))) throw Exception('Must be a university email (e.g. .edu, .edu.bd, .ac.bd)');
    return supabase.auth.resetPasswordForEmail(e);
  }

  Future<AppUser> getUser(String uid) async {
    final data = await supabase.from('users').select().eq('id', uid).single();
    return AppUser.fromMap(data);
  }

  // SECURITY: only allows updating safe fields — role cannot be changed here
  Future<void> updateUser(String uid, {String? name, String? department, String? semester}) async {
    final updates = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty)  updates['name'] = name.trim();
    if (department != null) updates['department'] = department;
    if (semester != null)   updates['semester'] = semester;
    if (updates.isEmpty) return;
    await supabase.from('users').update(updates).eq('id', uid);
  }
}

// Converts raw Supabase exceptions into human-readable messages
String friendlyAuthError(Object e) {
  final raw = e.toString();
  if (raw.contains('over_email_send_rate_limit') || raw.contains('429'))
    return 'Too many attempts. Please wait 60 seconds and try again.';
  if (raw.contains('is invalid') && raw.contains('Email address'))
    return 'Email domain not recognised. Use your real university email (e.g. zraian@daffodilvarsity.edu.bd). The domain must actually exist.';
  if (raw.contains('User already registered') || raw.contains('already registered'))
    return 'An account with this email already exists. Try signing in instead.';
  if (raw.contains('Invalid login credentials') || raw.contains('invalid_credentials'))
    return 'Incorrect email or password. Please try again.';
  if (raw.contains('Email not confirmed'))
    return 'Please confirm your email first. Check your inbox for a verification link.';
  if (raw.contains('SocketException') || raw.contains('NetworkException'))
    return 'No internet connection. Check your WiFi or mobile data.';
  if (raw.contains('weak_password') || raw.contains('Password should be'))
    return 'Password is too weak. Use at least 8 characters.';
  // Extract message field from AuthApiException(message: ..., ...)
  final m = RegExp(r'message: ([^,}\)]+)').firstMatch(raw);
  if (m != null) return m.group(1)!.trim();
  return raw
      .replaceAll(RegExp(r'Auth\w*Exception\('), '')
      .replaceAll('Exception: ', '')
      .replaceAll(')', '')
      .trim();
}
