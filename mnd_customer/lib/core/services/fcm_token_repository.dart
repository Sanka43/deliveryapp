import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';

/// Persists the device FCM token on [customers/{uid}] for server-side pushes.
class FcmTokenRepository {
  FcmTokenRepository({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> syncTokenForCurrentUser() async {
    if (kIsWeb) {
      return;
    }
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }
    try {
      final String? token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }
      await _firestore.collection(FirebaseCollections.customers).doc(user.uid).set(
        <String, dynamic>{
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> clearTokenForCurrentUser() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }
    try {
      await _firestore.collection(FirebaseCollections.customers).doc(user.uid).set(
        <String, dynamic>{
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}
