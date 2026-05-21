import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';

final Provider<RiderOrderNotificationsRepository> riderOrderNotificationsRepositoryProvider =
    Provider<RiderOrderNotificationsRepository>((Ref ref) {
  return RiderOrderNotificationsRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Writes in-app notifications for customer + vendor after rider accepts.
class RiderOrderNotificationsRepository {
  RiderOrderNotificationsRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> notifyOrderAccepted({
    required RiderDeliveryRequest request,
    required String riderName,
  }) async {
    final User? rider = _auth.currentUser;
    if (rider == null) {
      return;
    }

    final String ref = request.referenceForDisplay;
    final String title = 'Rider on the way';
    final String body =
        '$riderName accepted your delivery · $ref · ${request.vendorName}';

    final WriteBatch batch = _firestore.batch();
    final Timestamp now = Timestamp.now();

    final String? customerId = request.customerId?.trim();
    if (customerId != null && customerId.isNotEmpty) {
      final DocumentReference<Map<String, dynamic>> customerNotif = _firestore
          .collection(FirebaseCollections.notifications)
          .doc();
      batch.set(customerNotif, <String, dynamic>{
        'userId': customerId,
        'orderId': request.orderId,
        'type': 'rider_accepted',
        'title': title,
        'body': body,
        'read': false,
        'createdAt': now,
        'riderId': rider.uid,
        'audience': 'customer',
      });
    }

    final String? vendorId = request.vendorId?.trim();
    if (vendorId != null && vendorId.isNotEmpty) {
      final DocumentReference<Map<String, dynamic>> vendorNotif = _firestore
          .collection(FirebaseCollections.vendors)
          .doc(vendorId)
          .collection(FirebaseCollections.vendorNotifications)
          .doc();
      batch.set(vendorNotif, <String, dynamic>{
        'orderId': request.orderId,
        'type': 'rider_accepted',
        'title': 'Rider assigned',
        'body': 'A rider accepted order $ref and is heading to your store.',
        'read': false,
        'createdAt': now,
        'riderId': rider.uid,
      });

      final DocumentReference<Map<String, dynamic>> vendorUserNotif = _firestore
          .collection(FirebaseCollections.notifications)
          .doc();
      batch.set(vendorUserNotif, <String, dynamic>{
        'userId': vendorId,
        'orderId': request.orderId,
        'type': 'rider_accepted',
        'title': 'Rider assigned',
        'body': 'Order $ref — rider en route to pickup.',
        'read': false,
        'createdAt': now,
        'riderId': rider.uid,
        'audience': 'vendor',
        'vendorId': vendorId,
      });
    }

    try {
      await batch.commit();
    } catch (_) {
      // Rules may block until deployed; order claim still succeeds.
    }
  }
}
