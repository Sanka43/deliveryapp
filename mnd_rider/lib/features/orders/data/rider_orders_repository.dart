import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/earnings/domain/rider_cash_hold_message.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

final Provider<RiderOrdersRepository> riderOrdersRepositoryProvider =
    Provider<RiderOrdersRepository>((Ref ref) {
  return RiderOrdersRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

class RiderAssignedOrder {
  const RiderAssignedOrder({
    required this.id,
    required this.status,
    required this.storeName,
    required this.totalLkr,
    required this.createdAt,
    this.trackingNumber,
  });

  final String id;
  final String status;
  final String storeName;
  final int totalLkr;
  final DateTime? createdAt;
  final String? trackingNumber;

  String get referenceForDisplay {
    final String? t = trackingNumber?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return '—';
  }

  factory RiderAssignedOrder.fromDetail(RiderOrderDetail d) {
    return RiderAssignedOrder(
      id: d.id,
      status: d.status,
      storeName: d.storeName,
      totalLkr: d.totalLkr,
      createdAt: d.createdAt,
      trackingNumber: d.trackingNumber,
    );
  }

  factory RiderAssignedOrder.fromDoc(String id, Map<String, dynamic> data) {
    return RiderAssignedOrder.fromDetail(RiderOrderDetail.fromDoc(id, data));
  }
}

class RiderOrdersRepository {
  RiderOrdersRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _auth = auth,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection(FirebaseCollections.orders);

  /// Open pool: vendor marked ready and not yet claimed.
  Stream<List<RiderOrderDetail>> watchOpenJobs() {
    if (_auth.currentUser == null) {
      return Stream<List<RiderOrderDetail>>.value(const <RiderOrderDetail>[]);
    }
    return _orders
        .where('openForRiders', isEqualTo: true)
        .where('status', isEqualTo: 'ready')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(_mapDetailSnapshot);
  }

  Stream<List<RiderOrderDetail>> watchMyActiveOrders() {
    return watchAssignedToMe().map(
      (List<RiderAssignedOrder> list) => list
          .map(
            (RiderAssignedOrder o) => RiderOrderDetail(
              id: o.id,
              status: o.status,
              storeName: o.storeName,
              vendorId: '',
              customerId: null,
              totalLkr: o.totalLkr,
              deliveryFeeLkr: 0,
              items: const <RiderOrderLineItem>[],
              deliveryAddress: const RiderDeliveryAddress(
                line1: '',
                line2: '',
                city: '',
                phone: '',
              ),
              trackingNumber: o.trackingNumber,
              createdAt: o.createdAt,
            ),
          )
          .where((RiderOrderDetail d) => d.isActiveDelivery)
          .toList(),
    );
  }

  Stream<RiderOrderDetail?> watchOrderDetail(String orderId) {
    final String id = orderId.trim();
    if (id.isEmpty) {
      return Stream<RiderOrderDetail?>.value(null);
    }
    return _orders.doc(id).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snap) {
        if (!snap.exists || snap.data() == null) {
          return null;
        }
        return RiderOrderDetail.fromDoc(snap.id, snap.data()!);
      },
    );
  }

  Stream<List<RiderOrderDetail>> watchDeliveredHistory({int limit = 100}) {
    final User? u = _auth.currentUser;
    if (u == null) {
      return Stream<List<RiderOrderDetail>>.value(const <RiderOrderDetail>[]);
    }
    return _orders
        .where('riderId', isEqualTo: u.uid)
        .where('status', isEqualTo: 'delivered')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapDetailSnapshot);
  }

  Stream<List<RiderAssignedOrder>> watchAssignedToMe() {
    final User? u = _auth.currentUser;
    if (u == null) {
      return Stream<List<RiderAssignedOrder>>.value(const <RiderAssignedOrder>[]);
    }
    final Stream<List<RiderAssignedOrder>> byAssignedRiderId = _orders
        .where('assignedRiderId', isEqualTo: u.uid)
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots()
        .map(_mapAssignedSnapshot);
    final Stream<List<RiderAssignedOrder>> byRiderId = _orders
        .where('riderId', isEqualTo: u.uid)
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots()
        .map(_mapAssignedSnapshot);

    return _mergeOrderStreams(byAssignedRiderId, byRiderId);
  }

  List<RiderOrderDetail> _mapDetailSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              RiderOrderDetail.fromDoc(d.id, d.data()),
        )
        .toList(growable: false);
  }

  List<RiderAssignedOrder> _mapAssignedSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              RiderAssignedOrder.fromDoc(d.id, d.data()),
        )
        .toList(growable: false);
  }

  Stream<List<RiderAssignedOrder>> _mergeOrderStreams(
    Stream<List<RiderAssignedOrder>> first,
    Stream<List<RiderAssignedOrder>> second,
  ) {
    final StreamController<List<RiderAssignedOrder>> controller =
        StreamController<List<RiderAssignedOrder>>();
    List<RiderAssignedOrder> firstList = const <RiderAssignedOrder>[];
    List<RiderAssignedOrder> secondList = const <RiderAssignedOrder>[];

    void emitMerged() {
      final Map<String, RiderAssignedOrder> deduped = <String, RiderAssignedOrder>{
        for (final RiderAssignedOrder order in firstList) order.id: order,
        for (final RiderAssignedOrder order in secondList) order.id: order,
      };
      final List<RiderAssignedOrder> merged = deduped.values.toList()
        ..sort((RiderAssignedOrder a, RiderAssignedOrder b) {
          final DateTime aTime =
              a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime bTime =
              b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      controller.add(merged);
    }

    final StreamSubscription<List<RiderAssignedOrder>> sub1 = first.listen(
      (List<RiderAssignedOrder> value) {
        firstList = value;
        emitMerged();
      },
      onError: controller.addError,
    );
    final StreamSubscription<List<RiderAssignedOrder>> sub2 = second.listen(
      (List<RiderAssignedOrder> value) {
        secondList = value;
        emitMerged();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await sub1.cancel();
      await sub2.cancel();
    };
    return controller.stream;
  }

  Future<String?> claimOrder(String orderId) async {
    final User? u = _auth.currentUser;
    if (u == null) {
      return 'Not signed in.';
    }
    final String id = orderId.trim();
    if (id.isEmpty) {
      return 'Invalid order.';
    }

    try {
      await _firestore.runTransaction((Transaction tx) async {
        final DocumentReference<Map<String, dynamic>> orderRef = _orders.doc(id);
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(orderRef);
        if (!snap.exists || snap.data() == null) {
          throw StateError('Order not found.');
        }
        final Map<String, dynamic> data = snap.data()!;
        final String status = (data['status'] as String?)?.trim().toLowerCase() ?? '';
        final bool open = data['openForRiders'] == true;
        final String? assigned = (data['assignedRiderId'] as String?)?.trim();
        if (status != 'ready' || !open) {
          throw StateError('This job is no longer available.');
        }
        if (assigned != null && assigned.isNotEmpty) {
          throw StateError('Another rider already claimed this order.');
        }

        // Same cash-in-hand gate the rules enforce on the claim, checked here
        // so the rider gets a message they can act on.
        final DocumentSnapshot<Map<String, dynamic>> riderSnap = await tx.get(
          _firestore.collection(FirebaseCollections.riders).doc(u.uid),
        );
        if (riderSnap.data()?['cashHoldActive'] == true) {
          throw StateError(cashHoldClaimMessage(riderSnap.data()));
        }

        final String vendorId = (data['vendorId'] as String?)?.trim() ?? '';
        double? pickupLat;
        double? pickupLng;
        String? pickupAddress;

        if (vendorId.isNotEmpty) {
          final DocumentSnapshot<Map<String, dynamic>> vendorSnap = await tx.get(
            _firestore.collection(FirebaseCollections.vendors).doc(vendorId),
          );
          if (vendorSnap.exists && vendorSnap.data() != null) {
            final Map<String, dynamic> v = vendorSnap.data()!;
            final dynamic loc = v['location'];
            if (loc is GeoPoint) {
              pickupLat = loc.latitude;
              pickupLng = loc.longitude;
            } else {
              pickupLat = RiderOrderDetail.readDouble(v['latitude']);
              pickupLng = RiderOrderDetail.readDouble(v['longitude']);
            }
            pickupAddress = (v['address'] as String?)?.trim();
            if (pickupAddress == null || pickupAddress.isEmpty) {
              pickupAddress = (v['name'] as String?)?.trim();
            }
          }
        }

        final Map<String, dynamic> patch = <String, dynamic>{
          'assignedRiderId': u.uid,
          'riderId': u.uid,
          'openForRiders': false,
          'status': 'out_for_delivery',
          'riderAcceptedAt': FieldValue.serverTimestamp(),
          'riderStatusUpdatedAt': FieldValue.serverTimestamp(),
        };
        if (pickupLat != null && pickupLng != null) {
          patch['pickupLatitude'] = pickupLat;
          patch['pickupLongitude'] = pickupLng;
        }
        if (pickupAddress != null && pickupAddress.isNotEmpty) {
          patch['pickupAddress'] = pickupAddress;
        }
        tx.update(orderRef, patch);
      });
      return null;
    } on StateError catch (e) {
      return e.message;
    } catch (e) {
      return userFacingError(e, fallback: 'Could not claim order.');
    }
  }

  Future<RiderOrderDetail?> fetchOrderDetail(String orderId) async {
    final String id = orderId.trim();
    if (id.isEmpty) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap = await _orders.doc(id).get();
    if (!snap.exists || snap.data() == null) {
      return null;
    }
    return RiderOrderDetail.fromDoc(snap.id, snap.data()!);
  }

  Future<String?> updateOrderStatus({
    required String orderId,
    required String nextStatus,
  }) async {
    final User? u = _auth.currentUser;
    if (u == null) {
      return 'Not signed in.';
    }
    final String normalized = nextStatus.trim().toLowerCase();
    const Map<String, Set<String>> allowedFrom = <String, Set<String>>{
      'out_for_delivery': <String>{'picked_up', 'on_the_way', 'delivered'},
      'picked_up': <String>{'on_the_way', 'delivered'},
      'on_the_way': <String>{'delivered'},
    };
    const Set<String> allowed = <String>{
      'out_for_delivery',
      'picked_up',
      'on_the_way',
      'delivered',
    };
    if (!allowed.contains(normalized)) {
      return 'Invalid status.';
    }
    try {
      await _firestore.runTransaction((Transaction tx) async {
        final DocumentReference<Map<String, dynamic>> ref = _orders.doc(orderId);
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
        if (!snap.exists || snap.data() == null) {
          throw StateError('Order not found.');
        }
        final Map<String, dynamic> data = snap.data()!;
        final String assigned =
            (data['assignedRiderId'] as String?)?.trim() ??
            (data['riderId'] as String?)?.trim() ??
            '';
        if (assigned != u.uid) {
          throw StateError('This order is not assigned to you.');
        }
        final String from =
            (data['status'] as String?)?.trim().toLowerCase() ?? '';
        if (from == normalized) {
          return;
        }
        final Set<String>? nextAllowed = allowedFrom[from];
        if (nextAllowed == null || !nextAllowed.contains(normalized)) {
          throw StateError('Cannot change status from $from to $normalized.');
        }
        if (normalized == 'delivered' &&
            ((data['deliveryFeeMode'] as String?)?.trim() ?? '') ==
                'actual_trip') {
          throw StateError(
            'Complete this delivery via trip distance finalize.',
          );
        }
        final Map<String, dynamic> patch = <String, dynamic>{
          'status': normalized,
          'riderStatusUpdatedAt': FieldValue.serverTimestamp(),
        };
        if (normalized == 'picked_up') {
          patch['pickedUpAt'] = FieldValue.serverTimestamp();
        }
        if (normalized == 'on_the_way') {
          patch['onTheWayAt'] = FieldValue.serverTimestamp();
        }
        if (normalized == 'delivered') {
          patch['deliveredAt'] = FieldValue.serverTimestamp();
        }
        tx.update(ref, patch);
      });
      // Delivery earnings are credited server-side by the
      // onOrderDeliveredCreditRider Cloud Function when status -> delivered.
      return null;
    } on StateError catch (e) {
      return e.message;
    } on FirebaseException catch (e) {
      return e.message ?? 'Update failed.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Finalize actual-trip fee + mark delivered (server-authoritative).
  ///
  /// [confirmationCode] is required only for guest orders (no MND account) —
  /// the 4-digit code the customer received by SMS, proving a real recipient
  /// is at the address. The server rejects with `permission-denied` on a
  /// wrong code so the caller can prompt the rider to ask again.
  Future<CompleteDeliveryResult?> completeDeliveryOrder({
    required String orderId,
    required double traveledKm,
    String? confirmationCode,
  }) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('completeDeliveryOrder')
          .call(<String, dynamic>{
        'orderId': orderId.trim(),
        'traveledKm': traveledKm,
        if (confirmationCode != null && confirmationCode.trim().isNotEmpty)
          'confirmationCode': confirmationCode.trim(),
      });
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
      return CompleteDeliveryResult(
        orderId: (data['orderId'] as String?)?.trim() ?? orderId,
        traveledKm: RiderOrderDetail.readDouble(data['traveledKm']) ?? traveledKm,
        deliveryFeeLkr: RiderOrderDetail.readInt(data['deliveryFee']),
        subtotalLkr: RiderOrderDetail.readInt(data['subtotal']),
        serviceChargeLkr: RiderOrderDetail.readInt(data['serviceCharge']),
        totalLkr: RiderOrderDetail.readInt(data['total']),
        amountDueFromCustomerLkr:
            RiderOrderDetail.readInt(data['amountDueFromCustomer']),
        productsPaid: data['productsPaid'] == true,
      );
    } on FirebaseFunctionsException catch (e) {
      throw CompleteDeliveryException(
        (e.message?.trim().isNotEmpty ?? false)
            ? e.message!.trim()
            : 'Could not complete delivery.',
        code: e.code,
      );
    } catch (_) {
      throw const CompleteDeliveryException(
        'Could not complete delivery. Check your connection and try again.',
      );
    }
  }
}

class CompleteDeliveryResult {
  const CompleteDeliveryResult({
    required this.orderId,
    required this.traveledKm,
    required this.deliveryFeeLkr,
    required this.subtotalLkr,
    this.serviceChargeLkr = 0,
    required this.totalLkr,
    required this.amountDueFromCustomerLkr,
    required this.productsPaid,
  });

  final String orderId;
  final double traveledKm;
  final int deliveryFeeLkr;
  final int subtotalLkr;
  final int serviceChargeLkr;
  final int totalLkr;
  final int amountDueFromCustomerLkr;
  final bool productsPaid;
}

class CompleteDeliveryException implements Exception {
  const CompleteDeliveryException(this.message, {this.code});
  final String message;

  /// Firebase Functions error code, e.g. `permission-denied` (wrong
  /// confirmation code) or `resource-exhausted` (too many attempts, locked).
  final String? code;

  bool get isWrongConfirmationCode => code == 'permission-denied';
  bool get isConfirmationLocked => code == 'resource-exhausted';

  @override
  String toString() => message;
}

final StreamProvider<List<RiderAssignedOrder>> assignedRiderOrdersProvider =
    StreamProvider<List<RiderAssignedOrder>>((Ref ref) {
  return ref.watch(riderOrdersRepositoryProvider).watchAssignedToMe();
});

final StreamProvider<List<RiderOrderDetail>> openRiderJobsProvider =
    StreamProvider<List<RiderOrderDetail>>((Ref ref) {
  if (!ref.watch(riderIsApprovedToDriveProvider)) {
    return Stream<List<RiderOrderDetail>>.value(const <RiderOrderDetail>[]);
  }
  return ref.watch(riderOrdersRepositoryProvider).watchOpenJobs();
});

final StreamProvider<List<RiderOrderDetail>> riderDeliveredHistoryProvider =
    StreamProvider<List<RiderOrderDetail>>((Ref ref) {
  return ref.watch(riderOrdersRepositoryProvider).watchDeliveredHistory();
});

final AutoDisposeStreamProviderFamily<RiderOrderDetail?, String>
    riderOrderDetailProvider =
    StreamProvider.autoDispose.family<RiderOrderDetail?, String>((Ref ref, String orderId) {
  return ref.watch(riderOrdersRepositoryProvider).watchOrderDetail(orderId);
});
