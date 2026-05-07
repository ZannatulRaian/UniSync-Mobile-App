import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_client.dart';

// Key used to persist the user profile locally
const _kCachedUser = 'cached_user_profile';

class AuthService {
  User? get currentUser => supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  // ── Local cache helpers ────────────────────────────────────────────────────

  Future<void> _cacheUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCachedUser, jsonEncode({
      'id':          user.id,
      'name':        user.name,
      'email':       user.email,
      'department':  user.department,
      'semester':    user.semester,
      'student_id':  user.studentId,
      'role':        user.role,
      'photo_url':   user.photoUrl,
      'bookmarked_announcements': user.bookmarkedAnnouncements,
      'rsvped_events':            user.rsvpedEvents,
    }));
  }

  Future<AppUser?> _loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCachedUser);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppUser.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCachedUser);
  }

  // ── Auth actions ───────────────────────────────────────────────────────────

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
    required String department,
    required String semester,
    required String studentId,
  }) async {
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
    });

    final user = await getUser(uid);
    await _cacheUser(user);
    return user;
  }

  Future<AppUser> signIn(String email, String password) async {
    final e = email.trim().toLowerCase();
    final validDomains = ['.edu', '.edu.bd', '.ac.bd', '.ac.uk', '.ac.in'];
    if (!validDomains.any((d) => e.endsWith(d))) {
      throw Exception('Must be a university email (e.g. .edu, .edu.bd, .ac.bd)');
    }
    final res = await supabase.auth.signInWithPassword(
      email: e,
      password: password,
    );
    if (res.user == null) throw Exception('Login failed. Check your email and password.');
    final user = await getUser(res.user!.id);
    await _cacheUser(user);
    return user;
  }

  Future<void> signOut() async {
    await _clearCachedUser();
    await supabase.auth.signOut();
  }

  Future<void> sendPasswordReset(String email) {
    final e = email.trim().toLowerCase();
    final validDomains = ['.edu', '.edu.bd', '.ac.bd', '.ac.uk', '.ac.in'];
    if (!validDomains.any((d) => e.endsWith(d))) {
      throw Exception('Must be a university email (e.g. .edu, .edu.bd, .ac.bd)');
    }
    return supabase.auth.resetPasswordForEmail(e);
  }

  /// Fetch the user profile from Supabase.
  /// If offline, falls back to the locally cached copy.
  Future<AppUser> getUser(String uid) async {
    try {
      final data = await supabase.from('users').select().eq('id', uid).single();
      final user = AppUser.fromMap(data);
      await _cacheUser(user); // keep cache fresh whenever we fetch online
      return user;
    } catch (e) {
      // Network error — try the local cache
      final cached = await _loadCachedUser();
      if (cached != null && cached.id == uid) {
        print('[AuthService] Offline — using cached user profile');
        return cached;
      }
      rethrow; // no cache available, propagate the error
    }
  }

  Future<void> updateUser(String uid,
      {String? name, String? department, String? semester}) async {
    final updates = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) updates['name'] = name.trim();
    if (department != null) updates['department'] = department;
    if (semester != null)   updates['semester'] = semester;
    if (updates.isEmpty) return;
    await supabase.from('users').update(updates).eq('id', uid);

    // Refresh the cache after a successful update
    try {
      final fresh = await getUser(uid);
      await _cacheUser(fresh);
    } catch (_) {}
  }
}

// ── Friendly error messages ────────────────────────────────────────────────

String friendlyAuthError(Object e) {
  final raw = e.toString();
  if (raw.contains('over_email_send_rate_limit') || raw.contains('429'))
    return 'Too many attempts. Please wait 60 seconds and try again.';
  if (raw.contains('is invalid') && raw.contains('Email address'))
    return 'Email domain not recognised. Use your real university email.';
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
  final m = RegExp(r'message: ([^,}\)]+)').firstMatch(raw);
  if (m != null) return m.group(1)!.trim();
  return raw
      .replaceAll(RegExp(r'Auth\w*Exception\('), '')
      .replaceAll('Exception: ', '')
      .replaceAll(')', '')
      .trim();
}
