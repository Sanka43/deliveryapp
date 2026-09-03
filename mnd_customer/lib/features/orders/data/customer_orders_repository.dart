import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
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

  /// Firestore [orders] for [customerUid], newest first. Empty stream if uid is empty.
  Stream<List<CustomerOrderSummary>> watchMyOrders(String customerUid) {
    if (customerUid.isEmpty) {
      return Stream<List<CustomerOrderSummary>>.value(const <CustomerOrderSummary>[]);
    }
    return _firestore
        .collection(FirebaseCollections.orders)
        .where('customerId', isEqualTo: customerUid)
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

  /// Single order document owned by [customerUid] only.
  Stream<CustomerOrderDetail?> watchOrderDetail({
    required String orderId,
    required String customerUid,
  }) {
    if (customerUid.isEmpty) {
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
      if (owner != customerUid) {
        return null;
      }
      return CustomerOrderDetail.fromDoc(snapshot.id, data);
    });
  }

  /// Real-time location from `rider_locations/{riderId}` (no rider PII).
  ///
  /// Rules only allow reading this doc while `online == true`, so when a
  /// rider goes offline the listener gets `permission-denied` — and Firestore
  /// treats that as terminal, killing the underlying native listener for
  /// good. Mapping that error to `null` (empty/offline state) isn't enough by
  /// itself: without resubscribing, the stream would never receive updates
  /// again even after the rider goes back online and the doc starts changing.
  /// So on `permission-denied` we tear down and re-`snapshots()` on a timer,
  /// which picks the feed back up as soon as `online` flips true again.
  Stream<RiderLiveLocation?> watchRiderLiveLocation(String riderId) {
    if (riderId.isEmpty) {
      return Stream<RiderLiveLocation?>.value(null);
    }

    late final StreamController<RiderLiveLocation?> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
    Timer? retryTimer;

    void subscribe() {
      sub = _firestore
          .collection(FirebaseCollections.riderLocations)
          .doc(riderId)
          .snapshots()
          .listen(
        (DocumentSnapshot<Map<String, dynamic>> snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            controller.add(null);
            return;
          }
          controller.add(RiderLiveLocation.fromMap(snapshot.data()!));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (error is FirebaseException && error.code == 'permission-denied') {
            controller.add(null);
            unawaited(sub?.cancel());
            retryTimer?.cancel();
            retryTimer = Timer(const Duration(seconds: 5), subscribe);
            return;
          }
          controller.addError(error, stackTrace);
        },
      );
    }

    controller = StreamController<RiderLiveLocation?>.broadcast(
      onListen: subscribe,
      onCancel: () {
        retryTimer?.cancel();
        unawaited(sub?.cancel());
      },
    );
    return controller.stream;
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
    } on StateError catch (e) {
      return OrderCancellationResult.failure(
        userFacingError(e, fallback: 'Could not cancel order.'),
      );
    } catch (e) {
      return OrderCancellationResult.failure(
        userFacingError(e, fallback: 'Could not cancel order.'),
      );
    }
  }

  /// Submit a 1–5 star shop rating for a delivered order (one rating per order).
  Future<StoreRatingResult> submitStoreRating({
    required String orderId,
    required int stars,
    String? comment,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return StoreRatingResult.failure('Sign in to rate this store.');
    }
    if (stars < 1 || stars > 5) {
      return StoreRatingResult.failure('Choose a rating from 1 to 5 stars.');
    }

    final String trimmedComment = (comment ?? '').trim();
    if (trimmedComment.length > 500) {
      return StoreRatingResult.failure('Comment must be 500 characters or less.');
    }

    try {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentReference<Map<String, dynamic>> orderRef =
            _firestore.collection(FirebaseCollections.orders).doc(orderId);
        final DocumentReference<Map<String, dynamic>> ratingRef =
            _firestore.collection(FirebaseCollections.storeRatings).doc(orderId);

        final DocumentSnapshot<Map<String, dynamic>> orderSnap =
            await transaction.get(orderRef);
        if (!orderSnap.exists || orderSnap.data() == null) {
          throw StateError('Order not found.');
        }
        final Map<String, dynamic> order = orderSnap.data()!;
        if (order['customerId'] != user.uid) {
          throw StateError('You cannot rate this order.');
        }
        final String status =
            (order['status'] as String?)?.trim().toLowerCase() ?? '';
        if (status != 'delivered' && status != 'completed') {
          throw StateError('You can rate only after the order is finished.');
        }
        if (order['storeRated'] == true) {
          throw StateError('You already rated this order.');
        }

        final DocumentSnapshot<Map<String, dynamic>> existingRating =
            await transaction.get(ratingRef);
        if (existingRating.exists) {
          throw StateError('You already rated this order.');
        }

        final String vendorId = (order['vendorId'] as String?)?.trim() ?? '';
        if (vendorId.isEmpty) {
          throw StateError('Store is missing on this order.');
        }
        final String storeName =
            (order['storeName'] as String?)?.trim() ?? 'Store';

        transaction.set(ratingRef, <String, dynamic>{
          'orderId': orderId,
          'customerId': user.uid,
          'vendorId': vendorId,
          'storeName': storeName,
          'stars': stars,
          'comment': trimmedComment,
          'status': 'visible',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(orderRef, <String, dynamic>{
          'storeRated': true,
          'storeRatingStars': stars,
        });
      });
      return StoreRatingResult.success();
    } on StateError catch (e) {
      return StoreRatingResult.failure(
        userFacingError(e, fallback: 'Could not submit rating.'),
      );
    } catch (e) {
      return StoreRatingResult.failure(
        userFacingError(e, fallback: 'Could not submit rating.'),
      );
    }
  }

  /// Submit a 1–5 star rider rating for a delivered order (one rating per order).
  Future<StoreRatingResult> submitRiderRating({
    required String orderId,
    required int stars,
    String? comment,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return StoreRatingResult.failure('Sign in to rate this rider.');
    }
    if (stars < 1 || stars > 5) {
      return StoreRatingResult.failure('Choose a rating from 1 to 5 stars.');
    }

    final String trimmedComment = (comment ?? '').trim();
    if (trimmedComment.length > 500) {
      return StoreRatingResult.failure('Comment must be 500 characters or less.');
    }

    try {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentReference<Map<String, dynamic>> orderRef =
            _firestore.collection(FirebaseCollections.orders).doc(orderId);
        final DocumentReference<Map<String, dynamic>> ratingRef =
            _firestore.collection(FirebaseCollections.riderRatings).doc(orderId);

        final DocumentSnapshot<Map<String, dynamic>> orderSnap =
            await transaction.get(orderRef);
        if (!orderSnap.exists || orderSnap.data() == null) {
          throw StateError('Order not found.');
        }
        final Map<String, dynamic> order = orderSnap.data()!;
        if (order['customerId'] != user.uid) {
          throw StateError('You cannot rate this order.');
        }
        final String status =
            (order['status'] as String?)?.trim().toLowerCase() ?? '';
        if (status != 'delivered' && status != 'completed') {
          throw StateError('You can rate only after the order is finished.');
        }
        if (order['riderRated'] == true) {
          throw StateError('You already rated this rider.');
        }

        final DocumentSnapshot<Map<String, dynamic>> existingRating =
            await transaction.get(ratingRef);
        if (existingRating.exists) {
          throw StateError('You already rated this rider.');
        }

        final String riderId =
            ((order['riderId'] ?? order['assignedRiderId']) as String?)
                    ?.trim() ??
                '';
        if (riderId.isEmpty) {
          throw StateError('Rider is missing on this order.');
        }

        transaction.set(ratingRef, <String, dynamic>{
          'orderId': orderId,
          'customerId': user.uid,
          'riderId': riderId,
          'stars': stars,
          'comment': trimmedComment,
          'status': 'visible',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(orderRef, <String, dynamic>{
          'riderRated': true,
          'riderRatingStars': stars,
        });
      });
      return StoreRatingResult.success();
    } on StateError catch (e) {
      return StoreRatingResult.failure(
        userFacingError(e, fallback: 'Could not submit rating.'),
      );
    } catch (e) {
      return StoreRatingResult.failure(
        userFacingError(e, fallback: 'Could not submit rating.'),
      );
    }
  }
}

class StoreRatingResult {
  const StoreRatingResult._({required this.ok, this.message});

  factory StoreRatingResult.success() =>
      const StoreRatingResult._(ok: true);

  factory StoreRatingResult.failure(String message) =>
      StoreRatingResult._(ok: false, message: message);

  final bool ok;
  final String? message;
}
