import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';

final Provider<RiderPresenceRepository> riderPresenceRepositoryProvider =
    Provider<RiderPresenceRepository>((Ref ref) {
  return RiderPresenceRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

class RiderPresenceRepository {
  RiderPresenceRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> setOnline(bool online) async {
    final User? u = _auth.currentUser;
    if (u == null) {
      return;
    }
    await _firestore.collection(FirebaseCollections.riders).doc(u.uid).set(
      <String, dynamic>{
        'online': online,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
