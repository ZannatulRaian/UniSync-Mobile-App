import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  // Load .env — keys never touch source control
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url:     dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 10,
    ),
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
        if (_onboarded) return const LoginScreen();
        return OnboardingScreen(
          onDone: () => setState(() => _onboarded = true),
        );
      },
    );
  }
}
