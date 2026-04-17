import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_error_mapper.dart';
import 'staff_profile_repository.dart';

/// All Firebase Auth operations for staff (no local password storage).
class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    StaffProfileRepository? profileRepository,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _profiles = profileRepository ?? StaffProfileRepository();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final StaffProfileRepository _profiles;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final u = cred.user;
      if (u != null) {
        await _profiles.ensureProfileFromFirebaseUser(
          u,
          setCreatedAt: false,
        );
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception(mapFirebaseAuthError(e));
    }
  }

  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final u = cred.user;
      if (u == null) throw Exception('Account created but user is null.');
      await u.updateDisplayName(name.trim());
      await u.reload();
      final fresh = _auth.currentUser ?? u;
      await _profiles.ensureProfileFromFirebaseUser(
        fresh,
        displayNameOverride: name.trim(),
        avatarPreset: 'neutral',
        setCreatedAt: true,
      );
      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception(mapFirebaseAuthError(e));
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }
      final ga = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: ga.accessToken,
        idToken: ga.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      final u = cred.user;
      if (u != null) {
        final isNew = cred.additionalUserInfo?.isNewUser ?? false;
        await _profiles.ensureProfileFromFirebaseUser(
          u,
          displayNameOverride: googleUser.displayName,
          avatarPreset: 'neutral',
          setCreatedAt: isNew,
        );
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception(mapFirebaseAuthError(e));
    } on PlatformException catch (e) {
      // Android: com.google.android.gms.common.api.ApiException: 10 = DEVELOPER_ERROR
      // (SHA-1/SHA-256 for the signing keystore not added in Firebase Console).
      final msg = e.message ?? '';
      if (e.code == 'sign_in_failed' ||
          msg.contains('ApiException: 10') ||
          msg.contains('10:')) {
        throw Exception(
          'Google Sign-In is not configured for this app build. In Firebase Console → '
          'Project settings → Your apps → Android (com.elderlink.mobile), add the '
          'SHA-1 and SHA-256 for the keystore used to sign this APK (debug keystore '
          'for debug builds). Wait a few minutes, then try again.',
        );
      }
      throw Exception(
        msg.isNotEmpty ? msg : 'Google sign-in failed. Please try again.',
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(mapFirebaseAuthError(e));
    }
  }

  Future<void> signOut() async {
    await Future.wait<void>([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final u = _auth.currentUser;
    final email = u?.email;
    if (u == null || email == null) {
      throw Exception('Not signed in.');
    }
    try {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await u.reauthenticateWithCredential(cred);
      await u.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(mapFirebaseAuthError(e));
    }
  }
}
