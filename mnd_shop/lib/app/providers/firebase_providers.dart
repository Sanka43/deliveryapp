import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/services/shop_firebase_messaging_service.dart';

final Provider<FirebaseFirestore> firestoreProvider =
    Provider<FirebaseFirestore>((Ref ref) => FirebaseFirestore.instance);

final Provider<FirebaseStorage> firebaseStorageProvider =
    Provider<FirebaseStorage>((Ref ref) => FirebaseStorage.instance);

final Provider<FirebaseAuth> firebaseAuthProvider =
    Provider<FirebaseAuth>((Ref ref) => FirebaseAuth.instance);

final Provider<FirebaseFunctions> firebaseFunctionsProvider =
    Provider<FirebaseFunctions>(
  (Ref ref) => FirebaseFunctions.instanceFor(region: 'asia-south1'),
);

final Provider<FirebaseMessaging> firebaseMessagingProvider =
    Provider<FirebaseMessaging>((Ref ref) => FirebaseMessaging.instance);

final Provider<ShopFirebaseMessagingService> shopFirebaseMessagingServiceProvider =
    Provider<ShopFirebaseMessagingService>((Ref ref) {
  final ShopFirebaseMessagingService service = ShopFirebaseMessagingService(
    messaging: ref.watch(firebaseMessagingProvider),
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
