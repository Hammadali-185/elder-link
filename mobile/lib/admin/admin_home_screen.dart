import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_dashboard_screen.dart';
import 'admin_staff_screen.dart';
import 'admin_roles_screen.dart';
import 'admin_logs_screen.dart';
import 'admin_settings_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  late final ValueNotifier<bool> _showAdminQuickActions;

  @override
  void initState() {
    super.initState();
    _showAdminQuickActions = ValueNotifier<bool>(true);
    _reloadQuickActionsPref();
  }

  @override
  void dispose() {
    _showAdminQuickActions.dispose();
    super.dispose();
  }

  Future<void> _reloadQuickActionsPref() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    _showAdminQuickActions.value = p.getBool('admin_settings_show_activity') ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          AdminDashboardScreen(
            showQuickActionsListenable: _showAdminQuickActions,
            onReloadQuickActionsPref: _reloadQuickActionsPref,
            onNavigateToTab: (index) => setState(() => _currentIndex = index),
          ),
          const AdminStaffScreen(),
          AdminRolesScreen(),
          AdminLogsScreen(),
          AdminSettingsScreen(
            onPrefsChanged: _reloadQuickActionsPref,
          ),
        ],
      ),
      bottomNavigationBar: Material(
        color: const Color(0xFF17A2A2),
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Theme(
            data: Theme.of(context).copyWith(
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Color(0xFF17A2A2),
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.white54,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
                if (index == 0) {
                  _reloadQuickActionsPref();
                }
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white54,
              backgroundColor: const Color(0xFF17A2A2),
              elevation: 0,
              selectedFontSize: 13,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: 'Staff',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.badge),
                  label: 'Roles',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment),
                  label: 'Logs',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
