import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import 'services/staff_users_storage.dart';
import 'staff_gate_nav.dart';
import 'widgets/avatar_storage_io.dart' if (dart.library.html) 'widgets/avatar_storage_web.dart' as avatar_storage;
import 'screens/edit_profile_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/privacy_security_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  final String? staffName;
  
  const AccountSettingsScreen({super.key, this.staffName});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isChangingPassword = false;
  String _selectedAvatar = 'male'; // 'male' or 'female'
  Uint8List? _avatarImageBytes;
  final ImagePicker _picker = ImagePicker();
  String? _currentStaffName;

  @override
  void initState() {
    super.initState();
    _currentStaffName = widget.staffName;
    _loadAvatarPreference();
    _loadAvatarImage();
    _loadStaffName();
  }

  Future<void> _loadStaffName() async {
    final prefs = await SharedPreferences.getInstance();
    final user = await StaffUsersStorage.resolveCurrentUser(prefs);
    if (!mounted) return;
    setState(() {
      if (user != null) {
        _currentStaffName =
            user.name.isNotEmpty ? user.name : user.username;
      } else {
        _currentStaffName = widget.staffName;
      }
    });
  }

  Future<void> _loadAvatarImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bytes = await avatar_storage.loadAvatarBytes(prefs);
      if (mounted) setState(() {
        _avatarImageBytes = bytes;
        if (bytes != null) _selectedAvatar = 'custom';
      });
    } catch (e) {
      print('Error loading avatar image: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
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
        await StaffUsersStorage.syncCustomAvatarForCurrentUser(prefs);
        final bytes = await avatar_storage.loadAvatarBytes(prefs);
        if (mounted) {
          setState(() {
            _avatarImageBytes = bytes;
            _selectedAvatar = 'custom';
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

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatarPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final user = await StaffUsersStorage.resolveCurrentUser(prefs);
    if (!mounted) return;
    setState(() {
      _selectedAvatar = user?.avatar ?? 'male';
    });
  }

  Future<void> _saveAvatarPreference(String avatar) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionUser = await StaffUsersStorage.resolveCurrentUser(prefs);
    final u = sessionUser?.username;
    if (u == null || u.isEmpty) return;

    if (avatar != 'custom') {
      await prefs.remove('staff_avatar_image_path');
      await prefs.remove('staff_avatar_image_base64');
      if (mounted) {
        setState(() => _avatarImageBytes = null);
      }
    }

    await StaffUsersStorage.updateUserAvatar(prefs, u, avatar);
    final refreshed = await StaffUsersStorage.resolveCurrentUser(prefs);
    if (refreshed != null) {
      await StaffUsersStorage.applySession(prefs, refreshed);
    }

    setState(() {
      _selectedAvatar = avatar;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar updated!'),
          backgroundColor: Color(0xFF17A2A2),
        ),
      );
    }
  }

  Widget _buildAvatarIcon(String type, {double size = 40}) {
    return Icon(
      type == 'male' ? Icons.face : Icons.face_3,
      size: size,
      color: Colors.white,
    );
  }

  Future<void> _changePassword() async {
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

    setState(() {
      _isChangingPassword = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final sessionUser = await StaffUsersStorage.resolveCurrentUser(prefs);
      final u = sessionUser?.username;
      if (u == null || u.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not signed in'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final users = await StaffUsersStorage.getUsers(prefs);
      final match = StaffUsersStorage.findByCredentials(
        users,
        u,
        _oldPasswordController.text.trim(),
      );
      if (match == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Current password is incorrect'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final newPass = _newPasswordController.text.trim();
      await StaffUsersStorage.updateUserPassword(prefs, u, newPass);

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
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const deepMint = Color(0xFF17A2A2);
    const mint = Color(0xFF90EE90);

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
            // Profile Avatar Section
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
                                    deepMint,
                                    deepMint.withOpacity(0.7),
                                  ],
                                )
                              : null,
                          color: _avatarImageBytes != null ? Colors.transparent : null,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
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
                            : Center(
                                child: _buildAvatarIcon(_selectedAvatar, size: 50),
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
                  const SizedBox(height: 20),
                  // Avatar Selection
                  const Text(
                    'Select Avatar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Male Avatar
                      GestureDetector(
                        onTap: () => _saveAvatarPreference('male'),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _selectedAvatar == 'male'
                                  ? [deepMint, deepMint.withOpacity(0.7)]
                                  : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.2)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedAvatar == 'male'
                                  ? deepMint
                                  : Colors.grey.withOpacity(0.5),
                              width: _selectedAvatar == 'male' ? 3 : 2,
                            ),
                            boxShadow: _selectedAvatar == 'male'
                                ? [
                                    BoxShadow(
                                      color: deepMint.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: _buildAvatarIcon('male', size: 40),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Female Avatar
                      GestureDetector(
                        onTap: () => _saveAvatarPreference('female'),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _selectedAvatar == 'female'
                                  ? [deepMint, deepMint.withOpacity(0.7)]
                                  : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.2)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedAvatar == 'female'
                                  ? deepMint
                                  : Colors.grey.withOpacity(0.5),
                              width: _selectedAvatar == 'female' ? 3 : 2,
                            ),
                            boxShadow: _selectedAvatar == 'female'
                                ? [
                                    BoxShadow(
                                      color: deepMint.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: _buildAvatarIcon('female', size: 40),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Change Password Section
            const Text(
              'Change Password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            // Current Password
            _buildPasswordField(
              controller: _oldPasswordController,
              label: 'Current Password',
              isVisible: _isOldPasswordVisible,
              onVisibilityToggle: () {
                setState(() {
                  _isOldPasswordVisible = !_isOldPasswordVisible;
                });
              },
            ),
            const SizedBox(height: 16),
            // New Password
            _buildPasswordField(
              controller: _newPasswordController,
              label: 'New Password',
              isVisible: _isNewPasswordVisible,
              onVisibilityToggle: () {
                setState(() {
                  _isNewPasswordVisible = !_isNewPasswordVisible;
                });
              },
            ),
            const SizedBox(height: 16),
            // Confirm Password
            _buildPasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm New Password',
              isVisible: _isConfirmPasswordVisible,
              onVisibilityToggle: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
            ),
            const SizedBox(height: 24),
            // Change Password Button
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
                        'Change Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            // Other Account Options
            const Text(
              'Account Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.person_outline,
              title: 'Edit Profile',
              subtitle: 'Update your name and username',
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
                if (result == true) {
                  _loadStaffName();
                }
              },
            ),
            const SizedBox(height: 8),
            _buildOptionTile(
              icon: Icons.notifications_outlined,
              title: 'Notification Settings',
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
              title: 'Privacy & Security',
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
            // Logout Button
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
                  final prefs = await SharedPreferences.getInstance();
                  await StaffUsersStorage.logoutSession(prefs);

                  if (context.mounted) {
                    await replaceRouteAfterStaffLogout(context);
                  }
                },
                child: const Text(
                  'Log Out',
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
        border: Border.all(color: Colors.white.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
          prefixIcon: Icon(Icons.lock_outline, color: Colors.black.withOpacity(0.6)),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility_off : Icons.visibility,
              color: Colors.black.withOpacity(0.6),
            ),
            onPressed: onVisibilityToggle,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(
            color: Colors.black.withOpacity(0.6),
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
        border: Border.all(color: Colors.white.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: deepMint.withOpacity(0.15),
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
            color: Colors.black.withOpacity(0.6),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
