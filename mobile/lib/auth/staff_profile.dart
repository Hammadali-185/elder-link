import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore document `staff_profiles/{uid}` plus convenience fields.
class StaffProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String avatarPreset;
  final String? phone;
  final DateTime? updatedAt;

  const StaffProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.avatarPreset = 'neutral',
    this.phone,
    this.updatedAt,
  });

  factory StaffProfile.fromDoc(String uid, Map<String, dynamic> data) {
    return StaffProfile(
      uid: uid,
      displayName: (data['displayName'] as String? ?? '').trim(),
      email: (data['email'] as String? ?? '').trim(),
      photoUrl: data['photoUrl'] as String?,
      avatarPreset: (data['avatarPreset'] as String? ?? 'neutral').trim(),
      phone: data['phone'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toWriteMap() {
    return {
      'displayName': displayName,
      'email': email,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'avatarPreset': avatarPreset,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String get greetingName =>
      displayName.isNotEmpty ? displayName : (email.isNotEmpty ? email : 'Staff');
}
