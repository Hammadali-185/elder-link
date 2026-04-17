import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/providers/auth_providers.dart';
import 'auth/screens/firebase_login_screen.dart';
import 'auth/screens/firebase_sign_up_screen.dart';
import 'auth/staff_sign_out.dart';
import 'firebase_options.dart';
import 'join_screen.dart';
import 'staff_home_screen.dart';
import 'admin/admin_home_screen.dart';
import 'services/notification_service.dart';
import 'services/auto_lock_service.dart';
import 'services/analytics_service.dart';
import 'services/data_sharing_service.dart';
import 'services/api_service.dart';
import 'package:elderlink/karachi_time.dart';
import 'package:elderlink/services/music_player_service.dart';

/// Debug-only: when false, [AuthWrapper] signs staff out once on cold start so you always
/// land on the welcome flow. Firebase still persists until this runs.
const bool kAllowSavedStaffLoginInDebug = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Avoid [core/duplicate-app] on some Android setups where Firebase may already be
  // initialized by the platform before Dart runs.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  ensureKarachiTimeZones();

  runApp(
    const ProviderScope(
      child: MobileApp(),
    ),
  );
}

class _StartupInit extends StatefulWidget {
  final Widget child;
  const _StartupInit({required this.child});

  @override
  State<_StartupInit> createState() => _StartupInitState();
}

class _StartupInitState extends State<_StartupInit> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runDeferredInit();
    });
  }

  Future<void> _runDeferredInit() async {
    try {
      await ApiService.loadNetworkConfig();
      await ApiService.loadSavedElderUserInfo();
      ApiService.debugLogEndpoint();
    } catch (_) {}

    try {
      await MusicPlayerService.instance.ensureInitialized();
    } catch (_) {}

    try {
      await NotificationService.initialize();
      await NotificationService.load();
      // Ask for OS permission only after UI is visible; do not block startup.
      // ignore: unawaited_futures
      NotificationService.requestPermissions();
    } catch (_) {}

    try {
      await AnalyticsService.load();
    } catch (_) {}

    try {
      await DataSharingService.load();
    } catch (_) {}

    if (kDebugMode && !kAllowSavedStaffLoginInDebug) {
      try {
        await signOutStaffEverywhere();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MobileApp extends StatelessWidget {
  /// After staff logout: show Firebase login as root (optional; usually auth state handles UI).
  final bool openStaffLogin;

  /// After staff logout: show Firebase sign-up as root.
  final bool openStaffSignup;

  const MobileApp({
    super.key,
    this.openStaffLogin = false,
    this.openStaffSignup = false,
  });

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF90EE90);
    const deepMint = Color(0xFF17A2A2);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ElderLink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: deepMint,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 2,
        ),
      ),
      home: _StartupInit(
        child: AuthWrapper(
          openStaffLogin: openStaffLogin,
          openStaffSignup: openStaffSignup,
        ),
      ),
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  final bool openStaffLogin;
  final bool openStaffSignup;

  const AuthWrapper({
    super.key,
    this.openStaffLogin = false,
    this.openStaffSignup = false,
  });

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _prefsLoaded = false;
  bool _isAdminLoggedIn = false;
  bool _showLogoSplash = true;
  bool _dismissedPostLogoutStaffLogin = false;
  /// Avoid resetting inactivity on every [build] while signed in (that prevented auto-lock).
  bool _staffAutoLockSessionStarted = false;

  @override
  void initState() {
    super.initState();
    _loadAdminPrefs();
  }

  Future<void> _loadAdminPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final useSaved = !kDebugMode || kAllowSavedStaffLoginInDebug;
    var admin = false;
    if (useSaved) {
      admin = prefs.getBool('admin_logged_in') ?? false;
    }
    if (!mounted) return;
    setState(() {
      _isAdminLoggedIn = admin;
      _prefsLoaded = true;
    });
  }

  void _onAutoLockSignOut() {
    if (!mounted) return;
    signOutStaffEverywhere();
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
      final wasOut = prev?.valueOrNull == null;
      final nowIn = next.valueOrNull != null;
      if (wasOut && nowIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
        });
      }
    });

    final authAsync = ref.watch(authStateProvider);

    if (!_prefsLoaded || authAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isAdminLoggedIn) {
      return const AdminHomeScreen();
    }

    final firebaseUser = authAsync.valueOrNull;
    if (firebaseUser != null) {
      if (!_staffAutoLockSessionStarted) {
        _staffAutoLockSessionStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // ignore: discarded_futures
          AutoLockService.initialize(_onAutoLockSignOut);
          AutoLockService.updateActivity();
        });
      }
      return const StaffHomeScreen();
    }

    if (_staffAutoLockSessionStarted) {
      _staffAutoLockSessionStarted = false;
      AutoLockService.dispose();
    }

    if (widget.openStaffSignup &&
        !_dismissedPostLogoutStaffLogin &&
        !_isAdminLoggedIn) {
      return FirebaseSignUpScreen(
        onRootBack: () {
          setState(() {
            _dismissedPostLogoutStaffLogin = true;
            _showLogoSplash = false;
          });
        },
      );
    }
    if (widget.openStaffLogin &&
        !_dismissedPostLogoutStaffLogin &&
        !_isAdminLoggedIn) {
      return FirebaseLoginScreen(
        onRootBack: () {
          setState(() {
            _dismissedPostLogoutStaffLogin = true;
            _showLogoSplash = false;
          });
        },
      );
    }
    if (_showLogoSplash) {
      return _LogoSplashScreen(
        onDone: () {
          if (mounted) setState(() => _showLogoSplash = false);
        },
      );
    }
    return const WelcomeScreen();
  }
}

/// 3-second logo fade-in splash before the main page.
class _LogoSplashScreen extends StatefulWidget {
  final VoidCallback onDone;

  const _LogoSplashScreen({required this.onDone});

  @override
  State<_LogoSplashScreen> createState() => _LogoSplashScreenState();
}

class _LogoSplashScreenState extends State<_LogoSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const deepMint = Color(0xFF17A2A2);
    const mint = Color(0xFF90EE90);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFFFC),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF8FFFB),
              Color(0xFFEFFAF3),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        mint.withValues(alpha: 0.28),
                        deepMint.withValues(alpha: 0.18),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: deepMint.withValues(alpha: 0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'symbol.jpeg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.favorite,
                        size: 64,
                        color: deepMint,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ElderLink',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: deepMint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const mint = Color(0xFF90EE90);
    const deepMint = Color(0xFF17A2A2);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF6FFFA),
                  Color(0xFFE9FFF1),
                  Color(0xFFD8FBE2),
                ],
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: mint.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -90,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: deepMint.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 124,
                              height: 124,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    mint.withValues(alpha: 0.55),
                                    deepMint.withValues(alpha: 0.25),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'symbol.jpeg',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'ElderLink',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A calm, simple companion for care, reminders, and safety.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.60),
                                fontSize: 14.5,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: const [
                                _FeatureChip(icon: Icons.favorite, label: 'Health'),
                                _FeatureChip(icon: Icons.notifications_active, label: 'Reminders'),
                                _FeatureChip(icon: Icons.shield, label: 'Safety'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const JoinScreen()),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text(
                            'Welcome',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF90EE90).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black.withValues(alpha: 0.78)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}
