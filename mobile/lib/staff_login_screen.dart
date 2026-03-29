import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'services/staff_users_storage.dart';
import 'staff_home_screen.dart';
import 'widgets/avatar_storage_io.dart' if (dart.library.html) 'widgets/avatar_storage_web.dart' as avatar_storage;

class StaffLoginScreen extends StatefulWidget {
  /// When this screen is the app root (e.g. after logout), back goes to welcome instead of popping.
  final VoidCallback? onRootBack;
  final String? initialUsername;
  final bool initialSignUp;

  const StaffLoginScreen({
    super.key,
    this.onRootBack,
    this.initialUsername,
    this.initialSignUp = false,
  });

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  late bool _isSignUp;
  String _selectedGender = 'Male'; // Male or Female for Sign Up
  Uint8List? _avatarImageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialSignUp;
    final u = widget.initialUsername?.trim();
    if (u != null && u.isNotEmpty) {
      _usernameController.text = u;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatarImage() async {
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
        final bytes = await avatar_storage.loadAvatarBytes(prefs);
        if (mounted) {
          setState(() => _avatarImageBytes = bytes);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo added. You can change it anytime in Account Settings.'),
              backgroundColor: Color(0xFF17A2A2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAuth() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        final prefs = await SharedPreferences.getInstance();
        
        if (_isSignUp) {
          final name = _nameController.text.trim();
          final username = _usernameController.text.trim();
          final password = _passwordController.text.trim();

          if (name.isEmpty || username.isEmpty || password.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please fill in all fields'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          await prefs.reload();

          final avatar =
              _avatarImageBytes != null ? 'custom' : _selectedGender.toLowerCase();
          final newUser = StaffUser(
            id: '',
            username: username,
            password: password,
            name: name,
            avatar: avatar,
          );

          final duplicateMsg = await StaffUsersStorage.addUser(prefs, newUser);
          if (duplicateMsg != null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(duplicateMsg),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          if (avatar != 'custom') {
            await prefs.remove('staff_avatar_image_path');
            await prefs.remove('staff_avatar_image_base64');
          }

          await prefs.reload();
          final usersForSession = await StaffUsersStorage.getUsers(prefs);
          final savedUser = StaffUsersStorage.findByCredentials(
            usersForSession,
            username,
            password,
          );
          if (savedUser == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to save account. Please try again.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }
          if (avatar == 'custom') {
            await StaffUsersStorage.copyGlobalCustomAvatarToUser(
              prefs,
              savedUser.id,
            );
          }
          await StaffUsersStorage.applySession(prefs, savedUser);

          await prefs.reload();
          await Future.delayed(const Duration(milliseconds: 100));
          final verifyPrefs = await SharedPreferences.getInstance();
          await verifyPrefs.reload();

          final users = await StaffUsersStorage.getUsers(verifyPrefs);
          final ok = users.any(
            (u) => u.username == username && u.password == password,
          );
          print('Sign up - staff_users count: ${users.length}, verified: $ok');

          if (!ok) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to save account. Please try again.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created successfully!'),
                backgroundColor: Color(0xFF17A2A2),
              ),
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const StaffHomeScreen()),
              (route) => false,
            );
          }
        } else {
          final enteredUsername = _usernameController.text.trim();
          final enteredPassword = _passwordController.text.trim();

          final freshPrefs = await SharedPreferences.getInstance();
          await freshPrefs.reload();

          final users = await StaffUsersStorage.getUsers(freshPrefs);

          print('Login attempt: ${users.length} local account(s)');

          if (users.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No account found. Please create an account first.',
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } else {
            final match = StaffUsersStorage.findByCredentials(
              users,
              enteredUsername,
              enteredPassword,
            );

            if (match != null) {
              await StaffUsersStorage.applySession(freshPrefs, match);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Login successful!'),
                    backgroundColor: Color(0xFF17A2A2),
                  ),
                );
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const StaffHomeScreen()),
                );
              }
            } else {
              final byUser = users.any((u) => u.username == enteredUsername);
              final errorMsg = byUser
                  ? 'Password does not match'
                  : 'Invalid credentials';
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMsg),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          }
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
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const mint = Color(0xFF90EE90);
    const deepMint = Color(0xFF17A2A2);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 22),
          onPressed: () {
            if (widget.onRootBack != null) {
              widget.onRootBack!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          _isSignUp ? 'Staff Sign Up' : 'Staff Log In',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          const Icon(Icons.man, size: 22, color: Colors.blue),
          const SizedBox(width: 8),
          const Icon(Icons.woman, size: 22, color: Colors.pink),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          // Background gradient
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
          // Glow blobs
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: mint.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -130,
            left: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: deepMint.withOpacity(0.15),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        // Symbol
                        Container(
                          width: 100,
                          height: 100,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                mint.withOpacity(0.55),
                                deepMint.withOpacity(0.25),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'symbol.jpeg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _isSignUp ? 'Staff Sign Up' : 'Staff Log In',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSignUp
                              ? 'Create your account to continue'
                              : 'Enter your credentials to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.6),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Toggle between Sign Up and Log In
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.8)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isSignUp = false;
                                      _formKey.currentState?.reset();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !_isSignUp
                                          ? deepMint.withOpacity(0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Log In',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: !_isSignUp
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: !_isSignUp
                                            ? deepMint
                                            : Colors.black.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isSignUp = true;
                                      _formKey.currentState?.reset();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _isSignUp
                                          ? deepMint.withOpacity(0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Sign Up',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: _isSignUp
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _isSignUp
                                            ? deepMint
                                            : Colors.black.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Gender + Profile photo (Sign Up only)
                        if (_isSignUp) ...[
                          const Text(
                            'Select gender',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _selectedGender = 'Male'),
                                child: Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    color: _selectedGender == 'Male'
                                        ? Colors.blue.withOpacity(0.25)
                                        : Colors.grey.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _selectedGender == 'Male'
                                          ? Colors.blue
                                          : Colors.grey.withOpacity(0.5),
                                      width: _selectedGender == 'Male' ? 3 : 2,
                                    ),
                                    boxShadow: _selectedGender == 'Male'
                                        ? [
                                            BoxShadow(
                                              color: Colors.blue.withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.man,
                                      size: 44,
                                      color: _selectedGender == 'Male'
                                          ? Colors.blue.shade800
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 28),
                              GestureDetector(
                                onTap: () => setState(() => _selectedGender = 'Female'),
                                child: Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    color: _selectedGender == 'Female'
                                        ? Colors.pink.withOpacity(0.25)
                                        : Colors.grey.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _selectedGender == 'Female'
                                          ? Colors.pink
                                          : Colors.grey.withOpacity(0.5),
                                      width: _selectedGender == 'Female' ? 3 : 2,
                                    ),
                                    boxShadow: _selectedGender == 'Female'
                                        ? [
                                            BoxShadow(
                                              color: Colors.pink.withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.woman,
                                      size: 44,
                                      color: _selectedGender == 'Female'
                                          ? Colors.pink.shade700
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Profile photo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: _avatarImageBytes != null
                                      ? Colors.transparent
                                      : (_selectedGender == 'Male'
                                          ? Colors.blue.withOpacity(0.25)
                                          : Colors.pink.withOpacity(0.25)),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _selectedGender == 'Male'
                                        ? Colors.blue
                                        : Colors.pink,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
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
                                        child: Icon(
                                          _selectedGender == 'Male'
                                              ? Icons.man
                                              : Icons.woman,
                                          size: 50,
                                          color: _selectedGender == 'Male'
                                              ? Colors.blue.shade800
                                              : Colors.pink.shade700,
                                        ),
                                      ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickAvatarImage,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF17A2A2),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
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
                          const SizedBox(height: 6),
                          Text(
                            'Tap camera to add a photo (optional)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextField(
                            controller: _nameController,
                            label: 'Name',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Username field
                        _buildTextField(
                          controller: _usernameController,
                          label: 'Username',
                          icon: Icons.alternate_email,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a username';
                            }
                            if (value.trim().length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Password field
                        _buildPasswordField(),
                        const SizedBox(height: 28),
                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: deepMint,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            onPressed: _isLoading ? null : _handleAuth,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    _isSignUp ? 'Sign Up' : 'Log In',
                                    style: const TextStyle(
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
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.black.withOpacity(0.6)),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
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

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a password';
          }
          if (value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: Icon(Icons.lock_outline, color: Colors.black.withOpacity(0.6)),
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: Colors.black.withOpacity(0.6),
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
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
}
