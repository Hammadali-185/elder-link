import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_live_data.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
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
          'ElderLinks',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: _deepMint,
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
                'Live nurse status',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Realtime admin view based on current staff data',
                style: TextStyle(fontSize: 14, color: _textSecondary),
              ),
              const SizedBox(height: 20),
              if (_snapshot == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _LogCard(
                  title: _snapshot!.activeNurse == null
                      ? 'No nurse is signed in'
                      : '${displayStaffName(_snapshot!.activeNurse!)} is active now',
                  subtitle: _snapshot!.activeNurse == null
                      ? 'The admin panel is waiting for a live nurse session.'
                      : 'Current session is using the live nurse account.',
                  badge: _snapshot!.activeNurse == null ? 'Waiting' : 'Active',
                  color: _snapshot!.activeNurse == null ? Colors.orange : Colors.green,
                  icon: _snapshot!.activeNurse == null
                      ? Icons.hourglass_top_rounded
                      : Icons.login_rounded,
                  timestamp: formatAdminTimestamp(_snapshot!.refreshedAt),
                ),
                const SizedBox(height: 12),
                _LogCard(
                  title: '${_snapshot!.totalNurses} nurse account(s) detected',
                  subtitle: _snapshot!.nurses.isEmpty
                      ? 'No live nurse accounts are available yet.'
                      : _snapshot!.nurses
                          .map(displayStaffName)
                          .join(', '),
                  badge: 'Roster',
                  color: _deepMint,
                  icon: Icons.people_alt_rounded,
                  timestamp: formatAdminTimestamp(_snapshot!.refreshedAt),
                ),
                const SizedBox(height: 12),
                _LogCard(
                  title: 'Admin panel refreshed',
                  subtitle: 'This screen updates itself every few seconds to stay in sync.',
                  badge: 'Live',
                  color: Colors.indigo,
                  icon: Icons.sync_rounded,
                  timestamp: formatAdminTimestamp(_snapshot!.refreshedAt),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color color;
  final IconData icon;
  final String timestamp;

  const _LogCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.color,
    required this.icon,
    required this.timestamp,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A3C34),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badge,
                      style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.62)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.65), height: 1.3),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: Colors.black.withValues(alpha: 0.45)),
              const SizedBox(width: 6),
              Text(
                timestamp,
                style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.55), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
