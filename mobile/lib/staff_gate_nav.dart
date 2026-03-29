import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'services/staff_users_storage.dart';

/// After logout: full app shell with account picker if any users exist, else signup only.
Future<void> replaceRouteAfterStaffLogout(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final users = await StaffUsersStorage.getUsers(prefs);
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => users.isEmpty
          ? const MobileApp(openStaffSignup: true)
          : const MobileApp(openStaffLogin: true),
    ),
    (route) => false,
  );
}
