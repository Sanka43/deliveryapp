import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/core/services/firebase/firebase_auth_service.dart';
import 'package:mnd_rider/core/services/firebase/firebase_firestore_service.dart';
import 'package:mnd_rider/core/services/firebase/firebase_messaging_service.dart';
import 'package:mnd_rider/core/services/firebase/firebase_storage_service.dart';

final Provider<FirebaseAuth> firebaseAuthProvider =
    Provider<FirebaseAuth>((Ref ref) => FirebaseAuth.instance);

final Provider<FirebaseFirestore> firestoreProvider =
    Provider<FirebaseFirestore>((Ref ref) => FirebaseFirestore.instance);

final Provider<FirebaseStorage> firebaseStorageProvider =
    Provider<FirebaseStorage>((Ref ref) => FirebaseStorage.instance);

final Provider<FirebaseMessaging> firebaseMessagingProvider =
    Provider<FirebaseMessaging>((Ref ref) => FirebaseMessaging.instance);

final Provider<FirebaseAuthService> firebaseAuthServiceProvider =
    Provider<FirebaseAuthService>(
  (Ref ref) => FirebaseAuthService(ref.watch(firebaseAuthProvider)),
);

final Provider<FirebaseFirestoreService> firebaseFirestoreServiceProvider =
    Provider<FirebaseFirestoreService>(
  (Ref ref) => FirebaseFirestoreService(ref.watch(firestoreProvider)),
);

final Provider<FirebaseStorageService> firebaseStorageServiceProvider =
    Provider<FirebaseStorageService>(
  (Ref ref) => FirebaseStorageService(ref.watch(firebaseStorageProvider)),
);

final Provider<FirebaseMessagingService> firebaseMessagingServiceProvider =
    Provider<FirebaseMessagingService>(
  (Ref ref) => FirebaseMessagingService(
    messaging: ref.watch(firebaseMessagingProvider),
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  ),
);
