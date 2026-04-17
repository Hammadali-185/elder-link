/// Lightweight staff row for admin UI (Firebase-backed roster).
class StaffDisplayProfile {
  final String id;
  final String displayName;
  final String accountLabel;
  final String avatarPreset;

  const StaffDisplayProfile({
    required this.id,
    required this.displayName,
    required this.accountLabel,
    this.avatarPreset = 'neutral',
  });
}

String displayStaffProfileName(StaffDisplayProfile p) {
  final n = p.displayName.trim();
  return n.isNotEmpty ? n : p.accountLabel.trim();
}
