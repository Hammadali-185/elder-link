import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_theme.dart';
import '../widgets/google_sign_in_button.dart';
import 'firebase_sign_up_screen.dart';
import 'forgot_password_screen.dart';

/// Staff sign-in: email/password, Google, forgot password, link to sign-up.
class FirebaseLoginScreen extends ConsumerStatefulWidget {
  /// Optional back handler when this screen is shown as root after logout.
  final VoidCallback? onRootBack;

  const FirebaseLoginScreen({
    super.key,
    this.onRootBack,
  });

  @override
  ConsumerState<FirebaseLoginScreen> createState() => _FirebaseLoginScreenState();
}

class _FirebaseLoginScreenState extends ConsumerState<FirebaseLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signInWithEmail(
            email: _email.text.trim(),
            password: _password.text,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _googleLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (!msg.contains('cancelled')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthTheme.pageBg,
      body: Container(
        decoration: AuthTheme.pageGradientDecoration(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.onRootBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: widget.onRootBack,
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AuthTheme.mint.withValues(alpha: 0.55),
                            AuthTheme.deepMint.withValues(alpha: 0.25),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'symbol.jpeg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.favorite,
                            size: 40,
                            color: AuthTheme.deepMint,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Staff sign in',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A3C34),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use your ElderLink staff account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 32),
                  AuthTextField(
                    controller: _email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Email is required';
                      if (!s.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _password,
                    label: 'Password',
                    obscure: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'Password is required';
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading || _googleLoading
                          ? null
                          : () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AuthTheme.deepMint,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AuthPrimaryButton(
                    label: 'Sign in',
                    loading: _loading,
                    onPressed: _login,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.12))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.12))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GoogleSignInButton(
                    loading: _googleLoading,
                    onPressed: _google,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No account yet?',
                        style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
                      ),
                      TextButton(
                        onPressed: _loading || _googleLoading
                            ? null
                            : () async {
                                await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => const FirebaseSignUpScreen(),
                                  ),
                                );
                              },
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AuthTheme.deepMint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
