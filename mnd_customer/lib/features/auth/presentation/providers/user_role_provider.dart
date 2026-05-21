import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';

/// Resolves `role` from `customers/{uid}` when present; otherwise from `vendors/{uid}` (shop-only accounts).
final StreamProvider<String?> userRoleProvider = StreamProvider<String?>((Ref ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  final user = auth.currentUser;

  if (user == null) {
    return Stream<String?>.value(null);
  }

  return firestore
      .collection(FirebaseCollections.customers)
      .doc(user.uid)
      .snapshots()
      .asyncExpand((DocumentSnapshot<Map<String, dynamic>> userSnap) {
    final String? roleFromUser =
        (userSnap.data()?['role'] as String?)?.trim().toLowerCase();
    if (roleFromUser != null && roleFromUser.isNotEmpty) {
      return Stream<String?>.value(roleFromUser);
    }
    return firestore
        .collection(FirebaseCollections.vendors)
        .doc(user.uid)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> vSnap) {
      return (vSnap.data()?['role'] as String?)?.trim().toLowerCase();
    });
  });
});
