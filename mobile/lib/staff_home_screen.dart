import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/providers/auth_providers.dart';
import 'staff_gate_nav.dart';
import 'dashboard_screen.dart';
import 'elders_screen.dart';
import 'medicines_screen.dart';
import 'alerts_screen.dart';
import 'package:mobile/music_screen.dart';
import 'services/analytics_service.dart';
import 'widgets/activity_tracker.dart';
import 'services/api_service.dart';
import 'services/auto_lock_service.dart';
import 'services/staff_vital_alert_service.dart';

class StaffHomeScreen extends ConsumerStatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  ConsumerState<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends ConsumerState<StaffHomeScreen> {
  int _currentIndex = 0;
  Timer? _vitalPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSignedInOrLeave());
    AnalyticsService.logScreenView('staff_home');
    _vitalPollTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      final readings = await ApiService.getAllReadings();
      await StaffVitalAlertService.processReadings(readings);
    });
    Future.microtask(() async {
      final readings = await ApiService.getAllReadings();
      await StaffVitalAlertService.processReadings(readings);
    });
  }

  Future<void> _ensureSignedInOrLeave() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;
      await replaceRouteAfterStaffLogout(context);
    }
  }

  @override
  void dispose() {
    _vitalPollTimer?.cancel();
    super.dispose();
  }

  String? _resolveStaffName() {
    final profile = ref.watch(staffProfileProvider).valueOrNull;
    final user = ref.watch(authStateProvider).valueOrNull;
    if (profile != null) {
      return profile.greetingName;
    }
    if (user != null) {
      final n = user.displayName?.trim();
      if (n != null && n.isNotEmpty) return n;
      return user.email;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final staffName = _resolveStaffName();

    return ActivityTracker(
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            DashboardScreen(staffName: staffName),
            EldersScreen(staffName: staffName),
            MedicinesScreen(
              staffName: staffName,
              isActiveTab: _currentIndex == 2,
            ),
            AlertsScreen(staffName: staffName),
            MusicScreen(staffName: staffName),
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
                  AutoLockService.updateActivity();
                  final screenNames = [
                    'dashboard',
                    'elders',
                    'medicines',
                    'alerts',
                    'music',
                  ];
                  AnalyticsService.logScreenView(screenNames[index]);
                  setState(() => _currentIndex = index);
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
                    label: 'Elders',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.medication),
                    label: 'Medicines',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.notifications),
                    label: 'Alerts',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.music_note),
                    label: 'Music',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
