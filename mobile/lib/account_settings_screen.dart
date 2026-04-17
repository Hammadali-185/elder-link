import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/providers/auth_providers.dart';
import 'staff_gate_nav.dart';
import 'widgets/avatar_storage_io.dart' if (dart.library.html) 'widgets/avatar_storage_web.dart' as avatar_storage;
import 'screens/edit_profile_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/privacy_security_screen.dart';
import 'services/staff_avatar_local.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  final String? staffName;

  const AccountSettingsScreen({super.key, this.staffName});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isChangingPassword = false;
  Uint8List? _avatarImageBytes;
  final ImagePicker _picker = ImagePicker();
  String? _currentStaffName;

  @override
  void initState() {
    super.initState();
    _currentStaffName = widget.staffName;
    _loadFromFirebase();
  }

  Future<void> _loadFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await StaffAvatarLocal.restoreUidCustomAvatarToGlobalPrefs(prefs, user.uid);
    final bytes = await avatar_storage.loadAvatarBytes(prefs);
    final repo = ref.read(staffProfileRepositoryProvider);
    final doc = await repo.fetchProfile(user.uid);
    if (!mounted) return;
    setState(() {
      _currentStaffName = doc?.greetingName ??
          user.displayName ??
          user.email ??
          widget.staffName;
      _avatarImageBytes = bytes;
    });
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (image != null) {
        final prefs = await SharedPreferences.getInstance();
        await avatar_storage.savePickedImage(image, prefs);
        await StaffAvatarLocal.copyGlobalPickedImageToUid(prefs, user.uid);
        await ref.read(staffProfileRepositoryProvider).updateAvatarPreset('custom');
        final bytes = await avatar_storage.loadAvatarBytes(prefs);
        if (mounted) {
          setState(() {
            _avatarImageBytes = bytes;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar updated!'),
              backgroundColor: Color(0xFF17A2A2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in'), backgroundColor: Colors.red),
      );
      return;
    }

    if (user.providerData.any((p) => p.providerId == 'google.com')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google accounts manage password in Google settings.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_newPasswordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_newPasswordController.text.trim() != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      await ref.read(authServiceProvider).updatePassword(
            currentPassword: _oldPasswordController.text,
            newPassword: _newPasswordController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Color(0xFF17A2A2),
          ),
        );
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const deepMint = Color(0xFF17A2A2);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FFFA),
      appBar: AppBar(
        title: const Text(
          'Account Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: _avatarImageBytes == null
                              ? LinearGradient(
                                  colors: [
                                    Colors.blueGrey.shade400,
                                    Colors.blueGrey.shade300,
                                  ],
                                )
                              : null,
                          color: _avatarImageBytes != null ? Colors.transparent : null,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _avatarImageBytes != null
                            ? ClipOval(
                                child: Image.memory(
                                  _avatarImageBytes!,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImageFromGallery,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: deepMint,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentStaffName ?? 'Staff',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Change password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _oldPasswordController,
              label: 'Current password',
              isVisible: _isOldPasswordVisible,
              onVisibilityToggle: () {
                setState(() => _isOldPasswordVisible = !_isOldPasswordVisible);
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _newPasswordController,
              label: 'New password',
              isVisible: _isNewPasswordVisible,
              onVisibilityToggle: () {
                setState(() => _isNewPasswordVisible = !_isNewPasswordVisible);
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm new password',
              isVisible: _isConfirmPasswordVisible,
              onVisibilityToggle: () {
                setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: deepMint,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isChangingPassword ? null : _changePassword,
                child: _isChangingPassword
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Change password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Account options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.person_outline,
              title: 'Edit profile',
              subtitle: 'Update your display name and phone',
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
                if (result == true) {
                  _loadFromFirebase();
                }
              },
            ),
            const SizedBox(height: 8),
            _buildOptionTile(
              icon: Icons.notifications_outlined,
              title: 'Notification settings',
              subtitle: 'Manage your notification preferences',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildOptionTile(
              icon: Icons.security,
              title: 'Privacy & security',
              subtitle: 'Manage your privacy settings',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacySecurityScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) {
                    await replaceRouteAfterStaffLogout(context);
                  }
                },
                child: const Text(
                  'Log out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onVisibilityToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: !isVisible,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.lock_outline, color: Colors.black.withValues(alpha: 0.6)),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility_off : Icons.visibility,
              color: Colors.black.withValues(alpha: 0.6),
            ),
            onPressed: onVisibilityToggle,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(
            color: Colors.black.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    const deepMint = Color(0xFF17A2A2);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: deepMint.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: deepMint, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Colors.black.withValues(alpha: 0.6),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
