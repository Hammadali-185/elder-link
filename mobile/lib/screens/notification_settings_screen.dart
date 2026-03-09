import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _criticalAlerts = true;
  bool _medicineReminders = true;
  bool _healthUpdates = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('notif_push') ?? true;
      _emailNotifications = prefs.getBool('notif_email') ?? false;
      _criticalAlerts = prefs.getBool('notif_critical') ?? true;
      _medicineReminders = prefs.getBool('notif_medicine') ?? true;
      _healthUpdates = prefs.getBool('notif_health') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_push', _pushNotifications);
      await prefs.setBool('notif_email', _emailNotifications);
      await prefs.setBool('notif_critical', _criticalAlerts);
      await prefs.setBool('notif_medicine', _medicineReminders);
      await prefs.setBool('notif_health', _healthUpdates);

      // Reload notification service with new settings
      await NotificationService.load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_pushNotifications 
                ? 'Notification settings saved! Notifications are enabled.'
                : 'Notification settings saved! All notifications are disabled.'),
            backgroundColor: const Color(0xFF17A2A2),
          ),
        );
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    const deepMint = Color(0xFF17A2A2);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FFFA),
      appBar: AppBar(
        title: const Text(
          'Notification Settings',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSwitchTile(
              title: 'Push Notifications',
              subtitle: 'Receive push notifications on your device',
              value: _pushNotifications,
              onChanged: (val) => setState(() => _pushNotifications = val),
              icon: Icons.notifications_active,
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              title: 'Email Notifications',
              subtitle: 'Receive notifications via email',
              value: _emailNotifications,
              onChanged: (val) => setState(() => _emailNotifications = val),
              icon: Icons.email,
            ),
            const SizedBox(height: 24),
            const Text(
              'Alert Types',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              title: 'Critical Alerts',
              subtitle: 'Emergency and critical health alerts',
              value: _criticalAlerts,
              onChanged: (val) => setState(() => _criticalAlerts = val),
              icon: Icons.warning,
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              title: 'Medicine Reminders',
              subtitle: 'Reminders for medication schedules',
              value: _medicineReminders,
              onChanged: (val) => setState(() => _medicineReminders = val),
              icon: Icons.medication,
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              title: 'Health Updates',
              subtitle: 'Regular health monitoring updates',
              value: _healthUpdates,
              onChanged: (val) => setState(() => _healthUpdates = val),
              icon: Icons.favorite,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: deepMint,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isLoading ? null : _saveSettings,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    const deepMint = Color(0xFF17A2A2);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: deepMint.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: deepMint, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Colors.black.withOpacity(0.6),
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: deepMint,
        ),
      ),
    );
  }
}
