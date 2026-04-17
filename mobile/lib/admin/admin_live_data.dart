import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'staff_display_profile.dart';
import '../auth/staff_profile_repository.dart';

/// Snapshot for admin “Nurses” UI.
///
/// When the app has a **local admin session** (`admin_logged_in`), loads every
/// `staff_profiles` document from Firestore. Otherwise falls back to the current
/// Firebase user only. Deploy [firebase/firestore.rules](firebase/firestore.rules)
/// so reads are permitted for the admin roster (see rules comment).
class AdminStaffSnapshot {
  final List<StaffDisplayProfile> nurses;
  final StaffDisplayProfile? activeNurse;
  final DateTime refreshedAt;
  final String? rosterNote;

  const AdminStaffSnapshot({
    required this.nurses,
    required this.activeNurse,
    required this.refreshedAt,
    this.rosterNote,
  });

  int get totalNurses => nurses.length;
  int get activeNursesCount => activeNurse == null ? 0 : 1;
  int get inactiveNursesCount => totalNurses - activeNursesCount;
}

Future<AdminStaffSnapshot> loadAdminStaffSnapshot() async {
  final refreshedAt = DateTime.now();
  final user = FirebaseAuth.instance.currentUser;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final localAdmin = prefs.getBool('admin_logged_in') ?? false;

  if (localAdmin) {
    try {
      final qs = await FirebaseFirestore.instance
          .collection(StaffProfileRepository.collection)
          .get();
      final nurses = qs.docs.map((d) {
        final data = d.data();
        final dn = (data['displayName'] as String?)?.trim() ?? '';
        final em = (data['email'] as String?)?.trim() ?? '';
        var preset = (data['avatarPreset'] as String?)?.trim() ?? 'neutral';
        if (preset.isEmpty) preset = 'neutral';
        return StaffDisplayProfile(
          id: d.id,
          displayName: dn,
          accountLabel: em.isNotEmpty ? em : d.id,
          avatarPreset: preset,
        );
      }).toList();
      nurses.sort(
        (a, b) => displayStaffProfileName(a).toLowerCase().compareTo(
              displayStaffProfileName(b).toLowerCase(),
            ),
      );

      StaffDisplayProfile? activeNurse;
      if (user != null) {
        for (final n in nurses) {
          if (n.id == user.uid) {
            activeNurse = n;
            break;
          }
        }
      }

      return AdminStaffSnapshot(
        nurses: nurses,
        activeNurse: activeNurse,
        refreshedAt: refreshedAt,
        rosterNote: nurses.isEmpty
            ? 'No staff profiles in Firestore yet. Nurses appear after they sign in once on a device.'
            : null,
      );
    } catch (e) {
      return AdminStaffSnapshot(
        nurses: const [],
        activeNurse: null,
        refreshedAt: refreshedAt,
        rosterNote:
            'Could not load staff roster: $e. Deploy updated firestore.rules (read staff_profiles) from the mobile/firebase folder.',
      );
    }
  }

  if (user == null) {
    return AdminStaffSnapshot(
      nurses: const [],
      activeNurse: null,
      refreshedAt: refreshedAt,
      rosterNote:
          'No Firebase staff session on this device. Sign in as staff to see the active nurse, '
          'or open the admin panel for the full Firestore roster.',
    );
  }

  final repo = StaffProfileRepository();
  final doc = await repo.fetchProfile(user.uid);
  final preset = doc?.avatarPreset ?? 'neutral';
  final fromDoc = doc?.displayName.trim() ?? '';
  final fromAuth = user.displayName?.trim() ?? '';
  final displayName = fromDoc.isNotEmpty
      ? fromDoc
      : (fromAuth.isNotEmpty ? fromAuth : (user.email ?? user.uid));
  final email = user.email ?? '';

  final profile = StaffDisplayProfile(
    id: user.uid,
    displayName: displayName,
    accountLabel: email.isNotEmpty ? email : user.uid,
    avatarPreset: preset,
  );

  return AdminStaffSnapshot(
    nurses: [profile],
    activeNurse: profile,
    refreshedAt: refreshedAt,
    rosterNote: null,
  );
}

String formatAdminTimestamp(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day}/${local.month} $hour:$minute $suffix';
}
