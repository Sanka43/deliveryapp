import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
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

final StreamProvider<CustomerProfile?> customerProfileStreamProvider =
    StreamProvider<CustomerProfile?>((Ref ref) {
  return ref.watch(customerProfileRepositoryProvider).watchProfile();
});
