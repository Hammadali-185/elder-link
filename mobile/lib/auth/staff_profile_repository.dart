import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'staff_profile.dart';

class StaffProfileRepository {
  StaffProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String collection = 'staff_profiles';

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _firestore.collection(collection).doc(uid);

  Stream<StaffProfile?> watchProfile(String uid) {
    return _ref(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return StaffProfile.fromDoc(uid, snap.data()!);
    });
  }

  Future<StaffProfile?> fetchProfile(String uid) async {
    final snap = await _ref(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return StaffProfile.fromDoc(uid, snap.data()!);
  }

  /// Creates or merges profile from [user] after sign-in / sign-up.
  Future<void> ensureProfileFromFirebaseUser(
    User user, {
    String? displayNameOverride,
    String avatarPreset = 'neutral',
    bool setCreatedAt = false,
  }) async {
    final uid = user.uid;
    final email = user.email ?? '';
    final name = (displayNameOverride ?? user.displayName ?? '').trim();
    final displayName =
        name.isNotEmpty ? name : (email.isNotEmpty ? email.split('@').first : 'Staff');

    final ref = _ref(uid);
    final existing = await ref.get();
    final data = <String, dynamic>{
      'displayName': displayName,
      'email': email,
      if (user.photoURL != null && user.photoURL!.isNotEmpty)
        'photoUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final prevPreset = existing.data()?['avatarPreset'] as String?;
    if (!existing.exists || prevPreset == null || prevPreset.isEmpty) {
      data['avatarPreset'] = avatarPreset;
    }
    if (setCreatedAt || !existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> updateDisplayName(String displayName) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    await u.updateDisplayName(displayName.trim());
    await _ref(u.uid).set(
      {
        'displayName': displayName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Call only after [User.updateEmail] (requires recent re-auth) or for Google-linked accounts.
  Future<void> syncEmailToProfile(String email) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _ref(u.uid).set(
      {'email': email.trim(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> updateAvatarPreset(String preset) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    await _ref(u.uid).set(
      {
        'avatarPreset': preset,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updatePhone(String? phone) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    await _ref(u.uid).set(
      {
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (phone == null || phone.trim().isEmpty) 'phone': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
