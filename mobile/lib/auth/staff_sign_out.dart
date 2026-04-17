import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Signs out Firebase + Google (no local password session).
Future<void> signOutStaffEverywhere() async {
  await FirebaseAuth.instance.signOut();
  await GoogleSignIn().signOut();
}
