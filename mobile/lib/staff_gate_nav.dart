import 'package:flutter/material.dart';

import 'auth/staff_sign_out.dart';

/// Signs out Firebase staff session and returns to the app root route.
Future<void> replaceRouteAfterStaffLogout(BuildContext context) async {
  await signOutStaffEverywhere();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
}
