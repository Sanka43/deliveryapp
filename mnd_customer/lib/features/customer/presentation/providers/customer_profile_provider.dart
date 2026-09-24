import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/customer/data/customer_profile_repository.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';

final Provider<FirebaseStorage> firebaseStorageProvider =
    Provider<FirebaseStorage>((Ref ref) => FirebaseStorage.instance);

final Provider<CustomerProfileRepository> customerProfileRepositoryProvider =
    Provider<CustomerProfileRepository>((Ref ref) {
  return CustomerProfileRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(firebaseStorageProvider),
  );
});

/// Rebinds via [resolveAuthUser] so sign-out/sign-in cancels the previous
/// user's listener (authStateChanges().asyncExpand never did).
final StreamProvider<CustomerProfile?> customerProfileStreamProvider =
    StreamProvider<CustomerProfile?>((Ref ref) {
  final User? user = resolveAuthUser(ref);
  if (user == null) {
    return Stream<CustomerProfile?>.value(null);
  }
  return ref.watch(customerProfileRepositoryProvider).watchProfile(user);
});

/// Whether the signed-in customer still has to enter their name.
///
/// Emits null while unknown (signed out, or only a cache miss so far) so the
/// router doesn't bounce existing users to setup on a fresh device.
final StreamProvider<bool?> profileSetupRequiredProvider =
    StreamProvider<bool?>((Ref ref) {
  final User? user = resolveAuthUser(ref);
  if (user == null) {
    return Stream<bool?>.value(null);
  }
  return ref
      .watch(firestoreProvider)
      .collection(FirebaseCollections.customers)
      .doc(user.uid)
      .snapshots(includeMetadataChanges: true)
      .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists && snapshot.metadata.isFromCache) {
      return null;
    }
    return !CustomerProfile.merge(user, snapshot.data()).hasRealName;
  }).distinct();
});
