import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/home_page.dart';
import 'pages/email_confirmation_page.dart';
import 'pages/settings_page.dart';
import 'pages/create_post_page.dart';
import 'services/profile_service.dart';
import 'pages/public_profile_page.dart';
import 'services/theme_service.dart';
import 'pages/admin_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'MiraNet',
        theme: dark,
        darkTheme: dark,
        themeMode: mode,
        routes: {
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignupPage(),
        '/home': (_) => const HomePage(),
        '/email-confirmation': (ctx) {
          final arg = ModalRoute.of(ctx)?.settings.arguments;
          final email = (arg is String && arg.isNotEmpty) ? arg : 'ваша поштова скринька';
          return EmailConfirmationPage(email: email);
        },
  '/settings': (_) => const SettingsPage(),
  '/create-post': (_) => const CreatePostPage(),
        '/public-profile': (ctx) {
          final arg = ModalRoute.of(ctx)?.settings.arguments;
          final id = (arg is String) ? arg : '';
          return PublicProfilePage(userId: id);
        },
  '/admin': (_) => const AdminPage(),
        },
        home: const _Bootstrap(),
      ),
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<void> _boot;

  Future<void> _init() async {
    // Minimal display time for splash
    final sw = Stopwatch()..start();
    await SupabaseService.init();
    try {
      await ProfileService.ensureProfileForCurrentUser();
    } catch (_) {}
    // Ensure profile row on future auth changes
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
        if (event.session != null) {
          await ProfileService.ensureProfileForCurrentUser();
        }
      });
    } catch (_) {}
    final elapsed = sw.elapsedMilliseconds;
    const minMs = 700; // keep splash for at least 0.7s
    if (elapsed < minMs) {
      await Future.delayed(Duration(milliseconds: minMs - elapsed));
    }
  }

  @override
  void initState() {
    super.initState();
    _boot = _init();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _boot,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }
        return const _SessionGate();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF23A6D5), Color(0xFF23D5AB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 2, offset: Offset(0, 8)),
                ],
              ),
              child: Center(
                child: Text(
                  'M',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('MiraNet', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            const SizedBox(
              width: 140,
              child: LinearProgressIndicator(minHeight: 4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return StreamBuilder<AuthState>(
      stream: _authStream,
      initialData: session != null
          ? AuthState(AuthChangeEvent.signedIn, session)
          : AuthState(AuthChangeEvent.signedOut, null),
      builder: (context, snap) {
        final s = Supabase.instance.client.auth.currentSession;
        if (s == null) {
          return const LoginPage();
        }
        return const HomePage();
      },
    );
  }
}
