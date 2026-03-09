import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../join_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  static const _deepMint = Color(0xFF17A2A2);
  static const _bg = Color(0xFFF6FFFA);
  static const _textPrimary = Color(0xFF1A3C34);
  static const _textSecondary = Color(0xFF5A7A72);

  static const _keyNotifications = 'admin_settings_notifications';
  static const _keyEmailReports = 'admin_settings_email_reports';
  static const _keyShowActivityDashboard = 'admin_settings_show_activity';
  static const _keyLogRetentionDays = 'admin_settings_log_retention_days';

  bool _notifications = true;
  bool _emailReports = false;
  bool _showActivityOnDashboard = true;
  int _logRetentionDays = 30;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifications = prefs.getBool(_keyNotifications) ?? true;
      _emailReports = prefs.getBool(_keyEmailReports) ?? false;
      _showActivityOnDashboard = prefs.getBool(_keyShowActivityDashboard) ?? true;
      _logRetentionDays = prefs.getInt(_keyLogRetentionDays) ?? 30;
    });
  }

  Future<void> _setNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, value);
    setState(() => _notifications = value);
  }

  Future<void> _setEmailReports(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEmailReports, value);
    setState(() => _emailReports = value);
  }

  Future<void> _setShowActivityOnDashboard(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowActivityDashboard, value);
    setState(() => _showActivityOnDashboard = value);
  }

  Future<void> _setLogRetentionDays(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLogRetentionDays, value);
    setState(() => _logRetentionDays = value);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('admin_logged_in', false);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JoinScreen()),
      (route) => false,
    );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin settings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Preferences for the admin dashboard',
                style: TextStyle(fontSize: 14, color: _textSecondary),
              ),
              const SizedBox(height: 24),
              _buildSection('General'),
              _buildSettingSwitch(
                icon: Icons.notifications_active_rounded,
                title: 'Notifications',
                subtitle: 'Get alerts for critical events and reports',
                value: _notifications,
                onChanged: _setNotifications,
              ),
              _buildSettingSwitch(
                icon: Icons.dashboard_rounded,
                title: 'Show activity on dashboard',
                subtitle: 'Display recent staff activity on admin dashboard',
                value: _showActivityOnDashboard,
                onChanged: _setShowActivityOnDashboard,
              ),
              const SizedBox(height: 20),
              _buildSection('Reports'),
              _buildSettingSwitch(
                icon: Icons.email_rounded,
                title: 'Email reports',
                subtitle: 'Receive weekly summary by email',
                value: _emailReports,
                onChanged: _setEmailReports,
              ),
              const SizedBox(height: 20),
              _buildSection('Data'),
              _buildSettingDropdown(
                icon: Icons.history_rounded,
                title: 'Log retention',
                subtitle: 'Keep activity logs for',
                value: _logRetentionDays,
                options: const [7, 14, 30, 60, 90],
                onChanged: _setLogRetentionDays,
              ),
              const SizedBox(height: 28),
              _buildSection('Account'),
              _buildLogoutTile(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),
    );
  }

  Widget _buildSettingSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _deepMint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _deepMint, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _deepMint,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingDropdown({
    required IconData icon,
    required String title,
    required String subtitle,
    required int value,
    required List<int> options,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _deepMint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _deepMint, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          DropdownButton<int>(
            value: value,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down_rounded, color: _deepMint),
            items: options
                .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text('$d days'),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Sign out'),
              content: const Text(
                'You will be taken back to the main screen (Admin, Staff, Elder). Sign out?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: _deepMint),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          );
          if (confirm == true) await _logout();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign out (Admin)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Return to main screen',
                      style: TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }
}
