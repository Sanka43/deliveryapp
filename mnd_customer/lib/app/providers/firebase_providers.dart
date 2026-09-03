import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<FirebaseAuth> firebaseAuthProvider = Provider<FirebaseAuth>((Ref ref) {
  return FirebaseAuth.instance;
});

/// Rebuilds when sign-in state changes (unlike watching [FirebaseAuth] alone).
final StreamProvider<User?> authStateUserProvider = StreamProvider<User?>((Ref ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Signed-in user for Firestore streams that must rebind on auth changes.
///
/// Watches [authStateUserProvider]. While loading, falls back to sync
/// [FirebaseAuth.currentUser] so providers rebind immediately after sign-in
/// instead of briefly treating the user as null.
User? resolveAuthUser(Ref ref) {
  final AsyncValue<User?> authState = ref.watch(authStateUserProvider);
  final FirebaseAuth auth = ref.watch(firebaseAuthProvider);
  return authState.when(
    data: (User? u) => u,
    loading: () => auth.currentUser,
    error: (_, __) => null,
  );
}

final Provider<FirebaseFirestore> firestoreProvider = Provider<FirebaseFirestore>((Ref ref) {
  return FirebaseFirestore.instance;
});

final Provider<FirebaseMessaging> firebaseMessagingProvider = Provider<FirebaseMessaging>((Ref ref) {
  return FirebaseMessaging.instance;
});
