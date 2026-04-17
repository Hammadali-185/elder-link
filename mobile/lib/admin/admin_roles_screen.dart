import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/staff_account_avatar.dart';
import 'admin_live_data.dart';
import 'staff_display_profile.dart';

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  AdminStaffSnapshot? _snapshot;
  Timer? _refreshTimer;

  static const _deepMint = Color(0xFF17A2A2);
  static const _bg = Color(0xFFF6FFFA);
  static const _textPrimary = Color(0xFF1A3C34);
  static const _textSecondary = Color(0xFF5A7A72);

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadSnapshot());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSnapshot() async {
    final snapshot = await loadAdminStaffSnapshot();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'ElderLink',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: _deepMint,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSnapshot,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Roles & Permissions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Realtime roles for live nurse accounts.',
                style: TextStyle(fontSize: 14, color: _textSecondary),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                title: 'Nurse',
                subtitle: 'The live staff role used across the app',
                color: Colors.teal,
                icon: Icons.medical_services_rounded,
                permissions: const [
                  'View dashboard',
                  'View elders',
                  'Manage medicines',
                  'View alerts',
                  'Monitor music panel',
                  'Use account settings',
                ],
              ),
              const SizedBox(height: 26),
              Text(
                'Nurse accounts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Shows Firebase staff signed in on this device. Use a backend API for all accounts.',
                style: TextStyle(fontSize: 14, color: _textSecondary),
              ),
              const SizedBox(height: 14),
              if (_snapshot == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_snapshot!.nurses.isEmpty)
                _buildEmptyCard('No nurse accounts have been created yet.')
              else
                ..._snapshot!.nurses.map((nurse) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NurseRoleCard(
                        nurse: nurse,
                        isActive: _snapshot!.activeNurse?.id == nurse.id,
                      ),
                    )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          color: Colors.black.withValues(alpha: 0.65),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NurseRoleCard extends StatelessWidget {
  final StaffDisplayProfile nurse;
  final bool isActive;

  const _NurseRoleCard({
    required this.nurse,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isActive ? Colors.green : Colors.orange;
    final statusBg = isActive
        ? Colors.green.withValues(alpha: 0.10)
        : Colors.orange.withValues(alpha: 0.10);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StaffAccountAvatar(profile: nurse, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayStaffProfileName(nurse),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A3C34),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nurse',
                      style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.62)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.22)),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: Colors.black.withValues(alpha: 0.45)),
              const SizedBox(width: 6),
              Text(
                isActive ? 'Logged in right now' : 'Waiting for sign in',
                style: TextStyle(fontSize: 12.5, color: Colors.black.withValues(alpha: 0.65), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...const ['Dashboard', 'Elders', 'Medicines', 'Alerts', 'Music'].map(
                (label) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final List<String> permissions;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.permissions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A3C34),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.60)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: permissions
                .map(
                  (p) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color.withValues(alpha: 0.18)),
                    ),
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
