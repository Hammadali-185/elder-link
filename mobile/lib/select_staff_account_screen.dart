import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/staff_users_storage.dart';
import 'staff_login_screen.dart';
import 'widgets/staff_account_avatar.dart';

/// Lists saved staff accounts; choosing one opens login with username filled.
class SelectStaffAccountScreen extends StatefulWidget {
  final VoidCallback? onRootBack;

  const SelectStaffAccountScreen({super.key, this.onRootBack});

  @override
  State<SelectStaffAccountScreen> createState() =>
      _SelectStaffAccountScreenState();
}

class _SelectStaffAccountScreenState extends State<SelectStaffAccountScreen> {
  List<StaffUser>? _users;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final users = await StaffUsersStorage.getUsers(prefs);
    if (!mounted) return;
    users.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  void _openLogin({String? username}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffLoginScreen(
          initialUsername: username,
          initialSignUp: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mint = Color(0xFF90EE90);
    const deepMint = Color(0xFF17A2A2);

    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6FFFA),
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
          title: const Text(
            'Select account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final users = _users!;
    if (users.isEmpty) {
      return StaffLoginScreen(
        initialSignUp: true,
        onRootBack: widget.onRootBack,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FFFA),
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
        title: const Text(
          'Select account',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
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
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  'Who is signing in?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 12),
                ...users.map(
                  (u) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      elevation: 1,
                      shadowColor: Colors.black.withOpacity(0.06),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openLogin(username: u.username),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              StaffAccountAvatar(user: u, size: 52),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u.username,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (u.name.isNotEmpty &&
                                        u.name != u.username)
                                      Text(
                                        u.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black.withOpacity(0.5),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: deepMint.withOpacity(0.85),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  elevation: 1,
                  shadowColor: Colors.black.withOpacity(0.06),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openLogin(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: mint.withOpacity(0.35),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: deepMint.withOpacity(0.35),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.person_add_alt_1_outlined,
                              color: deepMint.withOpacity(0.9),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Use another account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: deepMint.withOpacity(0.85),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
