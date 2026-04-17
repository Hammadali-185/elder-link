import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/staff_account_avatar.dart';
import 'admin_live_data.dart';
import 'staff_display_profile.dart';

class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key});

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  AdminStaffSnapshot? _snapshot;
  Timer? _refreshTimer;

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
    const bg = Color(0xFFF6FFFA);
    const deepMint = Color(0xFF17A2A2);
    const textPrimary = Color(0xFF1A3C34);
    const textSecondary = Color(0xFF5A7A72);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('ElderLink', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: deepMint,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSnapshot,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Nurses',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Staff profiles from Firestore (each nurse appears after they sign in once)',
                style: TextStyle(fontSize: 14, color: textSecondary),
              ),
              const SizedBox(height: 20),
              if (_snapshot?.rosterNote != null) ...[
                _buildEmptyCard(_snapshot!.rosterNote!),
                const SizedBox(height: 16),
              ],
              if (_snapshot == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_snapshot!.nurses.isEmpty)
                _buildEmptyCard('No nurse accounts have been created yet.')
              else
                ..._snapshot!.nurses.map((nurse) {
                  final isActive = _snapshot!.activeNurse?.id == nurse.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NurseCard(
                      nurse: nurse,
                      isActive: isActive,
                      refreshedAt: _snapshot!.refreshedAt,
                    ),
                  );
                }),
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

class _NurseCard extends StatelessWidget {
  final StaffDisplayProfile nurse;
  final bool isActive;
  final DateTime refreshedAt;

  const _NurseCard({
    required this.nurse,
    required this.isActive,
    required this.refreshedAt,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isActive ? Colors.green : Colors.orange;
    final statusBg = isActive
        ? Colors.green.withValues(alpha: 0.10)
        : Colors.orange.withValues(alpha: 0.10);

    return Container(
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
      child: Row(
        children: [
          StaffAccountAvatar(profile: nurse, size: 52),
          const SizedBox(width: 14),
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
                  nurse.accountLabel,
                  style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.62)),
                ),
                const SizedBox(height: 6),
                Text(
                  isActive
                      ? 'Currently signed in as nurse'
                      : 'Available nurse account',
                  style: TextStyle(fontSize: 12.5, color: Colors.black.withValues(alpha: 0.58)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
              const SizedBox(height: 8),
              Text(
                formatAdminTimestamp(refreshedAt),
                style: TextStyle(fontSize: 11.5, color: Colors.black.withValues(alpha: 0.45)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
