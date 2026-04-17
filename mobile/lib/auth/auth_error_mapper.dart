import 'package:firebase_auth/firebase_auth.dart';

/// Maps [FirebaseAuthException] codes to short, user-facing English messages.
String mapFirebaseAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address does not look valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Try again or reset your password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase Console.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return 'Verification failed. Request a new code.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Something went wrong. Please try again.';
    }
  }
  return error.toString();
}
