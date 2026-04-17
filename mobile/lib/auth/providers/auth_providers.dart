import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_service.dart';
import '../staff_profile.dart';
import '../staff_profile_repository.dart';

final staffProfileRepositoryProvider = Provider<StaffProfileRepository>((ref) {
  return StaffProfileRepository();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    profileRepository: ref.watch(staffProfileRepositoryProvider),
  );
});

/// Emits [User?] whenever Firebase auth state changes (persisted across restarts).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Signed-in user's Firestore profile (null if signed out or doc missing).
final staffProfileProvider = StreamProvider<StaffProfile?>((ref) {
  final auth = ref.watch(authServiceProvider);
  final repo = ref.watch(staffProfileRepositoryProvider);
  return auth.authStateChanges.asyncExpand((user) {
    if (user == null) {
      return Stream<StaffProfile?>.value(null);
    }
    return repo.watchProfile(user.uid);
  });
});
