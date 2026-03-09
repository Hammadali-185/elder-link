import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'join_screen.dart';
import 'staff_home_screen.dart';
import 'admin/admin_home_screen.dart';
import 'services/notification_service.dart';
import 'services/auto_lock_service.dart';
import 'services/analytics_service.dart';
import 'services/data_sharing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service first
  await NotificationService.initialize();
  
  // Load all services
  await NotificationService.load();
  await AnalyticsService.load();
  await DataSharingService.load();
  
  runApp(const MobileApp());
}

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF90EE90); // light green
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
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isAdminLoggedIn = false;
  bool _showLogoSplash = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final useSavedLogin = !kDebugMode;
    final staffLoggedIn = useSavedLogin && (prefs.getBool('staff_logged_in') ?? false);
    final adminLoggedIn = useSavedLogin && (prefs.getBool('admin_logged_in') ?? false);

    if (kDebugMode) {
      print('AuthWrapper - Debug mode: starting at main page (ignore saved login)');
    } else {
      print('AuthWrapper - Staff logged in: $staffLoggedIn, Admin logged in: $adminLoggedIn');
    }

    setState(() {
      _isLoggedIn = staffLoggedIn;
      _isAdminLoggedIn = adminLoggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isAdminLoggedIn) {
      return const AdminHomeScreen();
    }

    if (_isLoggedIn) {
      AutoLockService.initialize(() {
        if (mounted) {
          final prefs = SharedPreferences.getInstance();
          prefs.then((p) => p.setBool('staff_logged_in', false));
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MobileApp()),
            (route) => false,
          );
        }
      });
      AutoLockService.updateActivity();
      return const StaffHomeScreen();
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
                        mint.withOpacity(0.5),
                        deepMint.withOpacity(0.35),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: deepMint.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
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
          // Soft gradient background (mobile-friendly)
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
          // Subtle glow blobs
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: mint.withOpacity(0.35),
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
                color: deepMint.withOpacity(0.18),
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
                      // Hero card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.8)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
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
                                    mint.withOpacity(0.55),
                                    deepMint.withOpacity(0.25),
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
                                color: Colors.black.withOpacity(0.60),
                                fontSize: 14.5,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Small feature chips
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
                      // Primary button
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
                      const SizedBox(height: 10),
                      Text(
                        'Tap to continue',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.55),
                          fontSize: 12.5,
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
        color: const Color(0xFF90EE90).withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black.withOpacity(0.78)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.black.withOpacity(0.78),
            ),
          ),
        ],
      ),
    );
  }
}
