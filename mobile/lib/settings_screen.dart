import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/providers/auth_providers.dart';
import 'screens/backend_settings_screen.dart';
import 'staff_gate_nav.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const deepMint = Color(0xFF17A2A2);

    Future<void> handleLogout() async {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) {
        await replaceRouteAfterStaffLogout(context);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FFFA),
      appBar: AppBar(
        title: const Text(
          'Settings',
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            leading: const Icon(Icons.dns_rounded, color: deepMint),
            title: const Text('Backend server'),
            subtitle: const Text('PC IP & port for API (required on phone APK)'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BackendSettingsScreen()),
              );
            },
          ),
          const Divider(),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 20),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: handleLogout,
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
    );
  }
}
