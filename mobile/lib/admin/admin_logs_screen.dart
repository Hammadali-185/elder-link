import 'package:flutter/material.dart';

class AdminLogsScreen extends StatelessWidget {
  const AdminLogsScreen({super.key});

  static const _deepMint = Color(0xFF17A2A2);
  static const _bg = Color(0xFFF6FFFA);
  static const _textPrimary = Color(0xFF1A3C34);
  static const _textSecondary = Color(0xFF5A7A72);

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activity & system logs',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Recent actions and events',
                style: TextStyle(fontSize: 14, color: _textSecondary),
              ),
              const SizedBox(height: 20),
              ..._logEntries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LogCard(entry: e),
                  )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogEntry {
  final String timestamp;
  final String user;
  final String action;
  final String detail;
  final LogType type;

  const _LogEntry({
    required this.timestamp,
    required this.user,
    required this.action,
    required this.detail,
    required this.type,
  });
}

enum LogType { login, activity, alert, system }

class _LogCard extends StatelessWidget {
  final _LogEntry entry;

  const _LogCard({required this.entry});

  Color get _typeColor {
    switch (entry.type) {
      case LogType.login:
        return Colors.teal;
      case LogType.activity:
        return AdminLogsScreen._deepMint;
      case LogType.alert:
        return Colors.orange;
      case LogType.system:
        return Colors.indigo;
    }
  }

  IconData get _typeIcon {
    switch (entry.type) {
      case LogType.login:
        return Icons.login_rounded;
      case LogType.activity:
        return Icons.touch_app_rounded;
      case LogType.alert:
        return Icons.notifications_active_rounded;
      case LogType.system:
        return Icons.settings_rounded;
    }
  }

  String get _typeLabel {
    switch (entry.type) {
      case LogType.login:
        return 'Login';
      case LogType.activity:
        return 'Activity';
      case LogType.alert:
        return 'Alert';
      case LogType.system:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                  color: _typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon, color: _typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.action,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A3C34),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.user,
                      style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.62)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _typeLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _typeColor),
                ),
              ),
            ],
          ),
          if (entry.detail.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              entry.detail,
              style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.65), height: 1.3),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: Colors.black.withOpacity(0.45)),
              const SizedBox(width: 6),
              Text(
                entry.timestamp,
                style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _logEntries = <_LogEntry>[
  _LogEntry(
    timestamp: 'Today, 10:22 AM',
    user: 'Meera Patel',
    action: 'Viewed elder vitals',
    detail: 'Elder: Fatima A. — BP 128/82, normal',
    type: LogType.activity,
  ),
  _LogEntry(
    timestamp: 'Today, 10:15 AM',
    user: 'Aisha Rahman',
    action: 'Admin login',
    detail: 'Signed in from web',
    type: LogType.login,
  ),
  _LogEntry(
    timestamp: 'Today, 9:58 AM',
    user: 'Chloe Martin',
    action: 'Alert resolved',
    detail: 'Abnormal BP alert for Elder Joseph K. — marked resolved',
    type: LogType.alert,
  ),
  _LogEntry(
    timestamp: 'Today, 9:41 AM',
    user: 'Grace Mensah',
    action: 'Care note added',
    detail: 'Elder: Ahmed R. — morning check completed',
    type: LogType.activity,
  ),
  _LogEntry(
    timestamp: 'Today, 9:12 AM',
    user: 'Daniel Okafor',
    action: 'Export report',
    detail: 'Weekly activity report generated',
    type: LogType.system,
  ),
  _LogEntry(
    timestamp: 'Today, 8:55 AM',
    user: 'Hassan Ali',
    action: 'Viewed elder vitals',
    detail: 'Elder: Peter M. — BP 135/78',
    type: LogType.activity,
  ),
  _LogEntry(
    timestamp: 'Yesterday, 6:48 PM',
    user: 'Lucas Nguyen',
    action: 'Staff login',
    detail: 'Signed in from mobile',
    type: LogType.login,
  ),
  _LogEntry(
    timestamp: 'Yesterday, 5:30 PM',
    user: 'System',
    action: 'Backup completed',
    detail: 'Daily backup finished successfully',
    type: LogType.system,
  ),
  _LogEntry(
    timestamp: 'Yesterday, 4:12 PM',
    user: 'Chloe Martin',
    action: 'Alert raised',
    detail: 'Panic button — Elder Maria S. (resolved)',
    type: LogType.alert,
  ),
];
