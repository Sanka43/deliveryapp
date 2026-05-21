import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';

final Provider<AdminOrdersRepository> adminOrdersRepositoryProvider =
    Provider<AdminOrdersRepository>((Ref ref) {
  return AdminOrdersRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

class AdminOrderRow {
  const AdminOrderRow({
    required this.id,
    required this.status,
    required this.vendorId,
    required this.customerId,
    required this.riderId,
    this.trackingNumber,
  });

  final String id;
  final String status;
  final String vendorId;
  final String customerId;
  final String? riderId;
  final String? trackingNumber;

  String get referenceForDisplay {
    final String? t = trackingNumber?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return '—';
  }

  factory AdminOrderRow.fromDoc(String id, Map<String, dynamic> data) {
    final String? raw =
        (data['riderId'] as String?)?.trim() ?? (data['assignedRiderId'] as String?)?.trim();
    final String? r = (raw == null || raw.isEmpty) ? null : raw;
    final String? tn = (data['trackingNumber'] as String?)?.trim();
    return AdminOrderRow(
      id: id,
      status: (data['status'] as String?)?.trim() ?? '',
      vendorId: (data['vendorId'] as String?)?.trim() ?? '',
      customerId: (data['customerId'] as String?)?.trim() ?? '',
      riderId: r,
      trackingNumber: (tn == null || tn.isEmpty) ? null : tn,
    );
  }
}

class AdminOrdersRepository {
  AdminOrdersRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<AdminOrderRow>> watchRecentOrders({int limit = 40}) {
    final User? u = _auth.currentUser;
    if (u == null) {
      return Stream<List<AdminOrderRow>>.value(const <AdminOrderRow>[]);
    }
    return _firestore
        .collection(FirebaseCollections.orders)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    AdminOrderRow.fromDoc(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  Future<String?> assignRider({
    required String orderId,
    required String riderUid,
  }) async {
    final String rid = riderUid.trim();
    if (rid.isEmpty) {
      return 'Rider UID is empty.';
    }
    if (_auth.currentUser == null) {
      return 'Not signed in.';
    }
    try {
      await _firestore.collection(FirebaseCollections.orders).doc(orderId).update(
        <String, dynamic>{
          'riderId': rid,
          'assignedRiderId': rid,
          'assignedAt': FieldValue.serverTimestamp(),
        },
      );
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not assign rider.';
    } catch (e) {
      return e.toString();
    }
  }
}
