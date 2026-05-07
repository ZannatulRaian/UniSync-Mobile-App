import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

final authServiceProvider = Provider((_) => AuthService());

final authStateProvider = StreamProvider<AuthState>((ref) =>
    Supabase.instance.client.auth.onAuthStateChange);

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AppUser?>((ref) =>
        AuthNotifier(ref.watch(authServiceProvider)));

// Keep backward-compatible alias
final currentUserProvider = authNotifierProvider;

class AuthNotifier extends StateNotifier<AppUser?> {
  final AuthService _auth;

  AuthNotifier(this._auth) : super(null) {
    _init();
  }

  Future<void> _init() async {
    final uid = _auth.currentUser?.id;
    if (uid == null) return;

    // getUser() now falls back to the local cache when offline,
    // so this works even with no internet connection.
    try {
      state = await _auth.getUser(uid);
    } catch (e) {
      print('[AuthNotifier] Could not load user: $e');
      // state stays null — the user will see a login screen
    }
  }

  Future<void> load(String uid) async {
    try {
      state = await _auth.getUser(uid);
    } catch (e) {
      print('[AuthNotifier] load() failed: $e');
    }
  }

  void clear()               => state = null;
  void update(AppUser u)     => state = u;
  void refreshUser(AppUser u) => state = u;
}
