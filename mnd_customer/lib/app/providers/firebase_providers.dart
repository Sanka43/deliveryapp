import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final Provider<FirebaseAuth> firebaseAuthProvider = Provider<FirebaseAuth>((Ref ref) {
  return FirebaseAuth.instance;
});

/// Rebuilds when sign-in state changes (unlike watching [FirebaseAuth] alone).
final StreamProvider<User?> authStateUserProvider = StreamProvider<User?>((Ref ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final Provider<FirebaseFirestore> firestoreProvider = Provider<FirebaseFirestore>((Ref ref) {
  return FirebaseFirestore.instance;
});

final Provider<FirebaseMessaging> firebaseMessagingProvider = Provider<FirebaseMessaging>((Ref ref) {
  return FirebaseMessaging.instance;
});

final Provider<GoogleSignIn> googleSignInProvider = Provider<GoogleSignIn>((Ref ref) {
  return GoogleSignIn(
    scopes: <String>['email'],
  );
});
