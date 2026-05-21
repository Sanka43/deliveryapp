import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

final Provider<RiderDeliveryRequestsRepository> riderDeliveryRequestsRepositoryProvider =
    Provider<RiderDeliveryRequestsRepository>((Ref ref) {
  return RiderDeliveryRequestsRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Realtime open jobs enriched with vendor pickup + distance fields.
class RiderDeliveryRequestsRepository {
  RiderDeliveryRequestsRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  final Map<String, Map<String, dynamic>> _vendorCache = <String, Map<String, dynamic>>{};

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection(FirebaseCollections.orders);

  /// Firestore: `openForRiders == true` && `status == ready` (indexed).
  Stream<List<RiderDeliveryRequest>> watchOpenDeliveryRequests({
    required double? riderLatitude,
    required double? riderLongitude,
  }) {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream<List<RiderDeliveryRequest>>.value(const <RiderDeliveryRequest>[]);
    }

    return _orders
        .where('openForRiders', isEqualTo: true)
        .where('status', isEqualTo: 'ready')
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots()
        .asyncMap(
          (QuerySnapshot<Map<String, dynamic>> snap) => _enrichSnapshot(
            snap,
            riderLat: riderLatitude,
            riderLng: riderLongitude,
          ),
        );
  }

  Future<List<RiderDeliveryRequest>> _enrichSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap, {
    required double? riderLat,
    required double? riderLng,
  }) async {
    final List<RiderDeliveryRequest> out = <RiderDeliveryRequest>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      final Map<String, dynamic> data = doc.data();
      final RiderOrderDetail order = RiderOrderDetail.fromDoc(doc.id, data);

      String? vendorAddress;
      double? vendorLat;
      double? vendorLng;
      final String vendorId = order.vendorId.trim();
      if (vendorId.isNotEmpty) {
        final Map<String, dynamic>? vendor = await _loadVendor(vendorId);
        if (vendor != null) {
          vendorAddress = (vendor['address'] as String?)?.trim();
          if (vendorAddress == null || vendorAddress.isEmpty) {
            vendorAddress = (vendor['name'] as String?)?.trim();
          }
          final dynamic loc = vendor['location'];
          if (loc is GeoPoint) {
            vendorLat = loc.latitude;
            vendorLng = loc.longitude;
          } else {
            vendorLat = RiderOrderDetail.readDouble(vendor['latitude']);
            vendorLng = RiderOrderDetail.readDouble(vendor['longitude']);
          }
        }
      }

      final RiderDeliveryRequest base = RiderDeliveryRequest.fromEnriched(
        order: order,
        riderLat: riderLat,
        riderLng: riderLng,
        vendorPickupAddress: vendorAddress,
        vendorPickupLat: vendorLat,
        vendorPickupLng: vendorLng,
      );

      out.add(base.withDeliveryType(RiderDeliveryType.fromOrderMap(data)));
    }
    return out;
  }

  Future<Map<String, dynamic>?> _loadVendor(String vendorId) async {
    if (_vendorCache.containsKey(vendorId)) {
      return _vendorCache[vendorId];
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _firestore.collection(FirebaseCollections.vendors).doc(vendorId).get();
      if (!snap.exists || snap.data() == null) {
        return null;
      }
      _vendorCache[vendorId] = snap.data()!;
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  Stream<RiderPosition?> watchRiderPosition() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream<RiderPosition?>.value(null);
    }
    return _firestore.collection(FirebaseCollections.riders).doc(user.uid).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snap) {
        if (!snap.exists || snap.data() == null) {
          return null;
        }
        final Map<String, dynamic> d = snap.data()!;
        final dynamic loc = d['currentLocation'] ?? d['location'];
        if (loc is GeoPoint) {
          return RiderPosition(latitude: loc.latitude, longitude: loc.longitude);
        }
        final double? lat = RiderOrderDetail.readDouble(d['latitude']);
        final double? lng = RiderOrderDetail.readDouble(d['longitude']);
        if (lat == null || lng == null) {
          return null;
        }
        return RiderPosition(latitude: lat, longitude: lng);
      },
    );
  }
}

class RiderPosition {
  const RiderPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
