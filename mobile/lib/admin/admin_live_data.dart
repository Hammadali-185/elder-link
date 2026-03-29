import 'package:shared_preferences/shared_preferences.dart';

import '../services/staff_users_storage.dart';

class AdminStaffSnapshot {
  final List<StaffUser> nurses;
  final StaffUser? activeNurse;
  final DateTime refreshedAt;

  const AdminStaffSnapshot({
    required this.nurses,
    required this.activeNurse,
    required this.refreshedAt,
  });

  int get totalNurses => nurses.length;
  int get activeNursesCount => activeNurse == null ? 0 : 1;
  int get inactiveNursesCount => totalNurses - activeNursesCount;
}

Future<AdminStaffSnapshot> loadAdminStaffSnapshot() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  final nurses = await StaffUsersStorage.getUsers(prefs);
  nurses.sort(
    (a, b) => displayStaffName(a).toLowerCase().compareTo(displayStaffName(b).toLowerCase()),
  );

  final activeNurse = await StaffUsersStorage.resolveCurrentUser(prefs);

  return AdminStaffSnapshot(
    nurses: nurses,
    activeNurse: activeNurse,
    refreshedAt: DateTime.now(),
  );
}

String displayStaffName(StaffUser user) {
  return user.name.trim().isNotEmpty ? user.name.trim() : user.username.trim();
}

String formatAdminTimestamp(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day}/${local.month} $hour:$minute $suffix';
}
