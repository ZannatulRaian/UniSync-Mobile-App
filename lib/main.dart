import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'providers/chat_provider.dart';
import 'screens/dashboard/main_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ── Initialize Supabase ──────────────────────────────────────────────────
  // Replace these two values with yours from the Supabase dashboard
  await Supabase.initialize(
    url:     'YOUR_SUPABASE_URL',      // e.g. https://abcdefgh.supabase.co
    anonKey: 'YOUR_SUPABASE_ANON_KEY', // long string starting with eyJ...
  );

  runApp(const ProviderScope(child: UniSyncApp()));
}

class UniSyncApp extends ConsumerWidget {
  const UniSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'UniSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      builder: (context, child) => AppBackground(child: child!),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();
  @override ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  // true = user has seen onboarding at least once this session
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      Future.microtask(() async {
        await ref.read(currentUserProvider.notifier).load(session.user.id);
        final user = ref.read(currentUserProvider);
        if (user != null) {
          ref.read(chatServiceProvider).joinPresence(user.uid, user.name);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:   (_, __) => const LoginScreen(),
      data: (state) {
        if (state.session != null) return const MainDashboard();

        // Not logged in — show onboarding first, then Login is the root
        if (_onboarded) return const LoginScreen();

        // First visit: show onboarding.
        // onDone is called when user taps Skip or finishes slides without signing up.
        // It brings them to LoginScreen (the root for unauthenticated users).
        return OnboardingScreen(
          onDone: () => setState(() => _onboarded = true),
        );
      },
    );
  }
}
