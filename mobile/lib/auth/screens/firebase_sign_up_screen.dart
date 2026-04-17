import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_theme.dart';
import '../widgets/google_sign_in_button.dart';

class FirebaseSignUpScreen extends ConsumerStatefulWidget {
  /// When this screen is the app root, use this instead of [Navigator.pop] for back.
  final VoidCallback? onRootBack;

  const FirebaseSignUpScreen({super.key, this.onRootBack});

  @override
  ConsumerState<FirebaseSignUpScreen> createState() => _FirebaseSignUpScreenState();
}

class _FirebaseSignUpScreenState extends ConsumerState<FirebaseSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signUpWithEmail(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
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
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
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
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (widget.onRootBack != null) {
                            widget.onRootBack!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A3C34),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join ElderLink as care staff',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 28),
                  AuthTextField(
                    controller: _name,
                    label: 'Full name',
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return 'Name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
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
                    obscure: _obscure1,
                    textInputAction: TextInputAction.next,
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                      icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                    ),
                    validator: (v) {
                      if ((v ?? '').length < 6) {
                        return 'At least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _confirm,
                    label: 'Confirm password',
                    obscure: _obscure2,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _signUp(),
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                      icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                    ),
                    validator: (v) {
                      if (v != _password.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Create account',
                    loading: _loading,
                    onPressed: _signUp,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
