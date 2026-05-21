import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_detail.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/rider_live_location.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_cancellation.dart';

class CustomerOrdersRepository {
  CustomerOrdersRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Firestore [orders] for the signed-in user, newest first. Empty stream if not signed in.
  Stream<List<CustomerOrderSummary>> watchMyOrders() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream<List<CustomerOrderSummary>>.value(const <CustomerOrderSummary>[]);
    }
    return _firestore
        .collection(FirebaseCollections.orders)
        .where('customerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            return snapshot.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                    return CustomerOrderSummary.fromDoc(doc.id, doc.data());
                  },
                )
                .toList(growable: false);
          },
        );
  }

  /// Single order document for the signed-in customer only.
  Stream<CustomerOrderDetail?> watchOrderDetail(String orderId) {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream<CustomerOrderDetail?>.value(null);
    }
    return _firestore
        .collection(FirebaseCollections.orders)
        .doc(orderId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      final Map<String, dynamic> data = snapshot.data()!;
      final String? owner = data['customerId'] as String?;
      if (owner != user.uid) {
        return null;
      }
      return CustomerOrderDetail.fromDoc(snapshot.id, data);
    });
  }

  /// Real-time location for a rider document (no auth check — secure in Firestore rules).
  Stream<RiderLiveLocation?> watchRiderLiveLocation(String riderId) {
    if (riderId.isEmpty) {
      return Stream<RiderLiveLocation?>.value(null);
    }
    return _firestore
        .collection(FirebaseCollections.riders)
        .doc(riderId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return RiderLiveLocation.fromMap(snapshot.data()!);
    });
  }

  /// Customer cancels their own order with a reason (validated in a transaction).
  Future<OrderCancellationResult> cancelOrderByCustomer({
    required String orderId,
    required String reasonId,
    String? otherDetail,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return OrderCancellationResult.failure('Sign in to cancel an order.');
    }

    final String trimmedReason = reasonId.trim().toLowerCase();
    if (trimmedReason.isEmpty) {
      return OrderCancellationResult.failure('Choose a cancellation reason.');
    }

    final String? detail = otherDetail?.trim();
    final bool needsDetail = trimmedReason == 'other';
    if (needsDetail && (detail == null || detail.isEmpty)) {
      return OrderCancellationResult.failure('Please describe your reason.');
    }

    try {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentReference<Map<String, dynamic>> ref =
            _firestore.collection(FirebaseCollections.orders).doc(orderId);
        final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction.get(ref);
        if (!snapshot.exists || snapshot.data() == null) {
          throw StateError('Order not found.');
        }
        final Map<String, dynamic> data = snapshot.data()!;
        if (data['customerId'] != user.uid) {
          throw StateError('You cannot cancel this order.');
        }
        final String status =
            (data['status'] as String?)?.trim().toLowerCase() ?? '';
        if (!OrderCancellationPolicy.customerMayCancel(status)) {
          throw StateError('This order can no longer be cancelled.');
        }

        final Map<String, dynamic> update = <String, dynamic>{
          'status': 'cancelled',
          'cancellationReason': trimmedReason,
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': 'customer',
        };
        if (detail != null && detail.isNotEmpty) {
          update['cancellationReasonDetail'] = detail;
        }

        transaction.update(ref, update);
      });
      return OrderCancellationResult.success();
    } on FirebaseException catch (e) {
      return OrderCancellationResult.failure(e.message ?? 'Could not cancel order.');
    } on StateError catch (e) {
      return OrderCancellationResult.failure(e.message);
    } catch (e) {
      return OrderCancellationResult.failure(e.toString());
    }
  }
}
