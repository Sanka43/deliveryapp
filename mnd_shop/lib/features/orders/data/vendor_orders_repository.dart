import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_open_hours.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_sales_aggregator.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_sales_summary.dart';
import 'package:mnd_shop/features/orders/domain/vendor_order_status.dart';

final Provider<VendorOrdersRepository> vendorOrdersRepositoryProvider =
    Provider<VendorOrdersRepository>((Ref ref) {
      return VendorOrdersRepository(
        firestore: ref.watch(firestoreProvider),
        auth: ref.watch(firebaseAuthProvider),
      );
    });

class VendorOrderBoard {
  const VendorOrderBoard({
    required this.incoming,
    required this.kitchen,
    required this.readyForPickup,
    required this.outForDelivery,
    required this.completed,
    required this.cancelled,
    required this.salesSummary,
    this.isTruncated = false,
  });

  final List<VendorPendingOrder> incoming;
  final List<VendorPendingOrder> kitchen;
  final List<VendorPendingOrder> readyForPickup;

  /// Reserved for a future `shipping` / out-for-delivery status; empty with current schema.
  final List<VendorPendingOrder> outForDelivery;
  final List<VendorPendingOrder> completed;
  final List<VendorPendingOrder> cancelled;
  final VendorSalesSummary salesSummary;

  /// True when the Firestore query hit the safety limit and older orders may be hidden.
  final bool isTruncated;

  static const VendorOrderBoard empty = VendorOrderBoard(
    incoming: <VendorPendingOrder>[],
    kitchen: <VendorPendingOrder>[],
    readyForPickup: <VendorPendingOrder>[],
    outForDelivery: <VendorPendingOrder>[],
    completed: <VendorPendingOrder>[],
    cancelled: <VendorPendingOrder>[],
    salesSummary: VendorSalesSummary.zero,
  );

  /// Active pipeline (excludes completed terminal state).
  int get activeCount =>
      incoming.length +
      kitchen.length +
      readyForPickup.length +
      outForDelivery.length;
}

class VendorOrdersRepository {
  VendorOrdersRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection(FirebaseCollections.orders);

  CollectionReference<Map<String, dynamic>> get _vendors =>
      _firestore.collection(FirebaseCollections.vendors);

  Future<bool> _isAuthorizedVendorId(String vendorId) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    final String uid = user.uid.trim();
    final String id = vendorId.trim();
    if (id.isEmpty) {
      return false;
    }
    if (id == uid) {
      return true;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap = await _vendors
        .doc(id)
        .get();
    final String owner = (snap.data()?['uid'] as String?)?.trim() ?? '';
    return snap.exists && owner == uid;
  }

  Future<bool> _canMutateOrder(String orderId) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap = await _orders
        .doc(orderId)
        .get();
    if (!snap.exists) {
      return false;
    }
    final String vendorId = (snap.data()?['vendorId'] as String?)?.trim() ?? '';
    return _isAuthorizedVendorId(vendorId);
  }

  /// Clears any `order_reminder` inbox entries for [orderId] once it's no
  /// longer `placed` — e.g. the vendor confirmed it from the board rather
  /// than by tapping the reminder notification itself. The reminder doc ids
  /// are deterministic (`sweepStalePlacedOrders` writes at most two,
  /// `_order_reminder_1`/`_order_reminder_2`) and usually don't exist at all
  /// if no reminder ever fired — `.update()` is used instead of
  /// `.set(merge: true)` so a missing doc is a safe no-op rather than
  /// creating an empty stub notification.
  ///
  /// Best-effort only: this runs *after* the status write has committed, so a
  /// failure here must never be reported as a failed accept/reject. A missing
  /// reminder doc comes back as `permission-denied`, not `not-found` — the
  /// security rule for these docs inspects `resource.data`, which can't be
  /// evaluated when the document doesn't exist — so every Firestore error is
  /// swallowed rather than just `not-found`.
  Future<void> _clearOrderReminderNotifications({
    required String vendorId,
    required String orderId,
  }) async {
    final String v = vendorId.trim();
    if (v.isEmpty) {
      return;
    }
    final CollectionReference<Map<String, dynamic>> notifications = _firestore
        .collection(FirebaseCollections.vendors)
        .doc(v)
        .collection(FirebaseCollections.vendorNotifications);
    final Map<String, dynamic> patch = <String, dynamic>{
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    };
    for (final String suffix in const <String>['1', '2']) {
      try {
        await notifications.doc('${orderId}_order_reminder_$suffix').update(patch);
      } on FirebaseException catch (e) {
        if (kDebugMode) {
          debugPrint('clearOrderReminderNotifications skipped: ${e.code}');
        }
      }
    }
  }

  /// Whether the store is accepting orders (`active != false`).
  ///
  /// Missing vendor docs default to closed so an unlinked or deleted storefront
  /// cannot accidentally keep accepting orders.
  Stream<bool> watchVendorActive(String vendorId) {
    final String id = vendorId.trim();
    if (id.isEmpty) {
      return Stream<bool>.value(false);
    }
    return _vendors.doc(id).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> s,
    ) {
      if (!s.exists || s.data() == null) {
        return false;
      }
      final dynamic a = s.data()!['active'];
      return a != false;
    });
  }

  Future<String?> setVendorActive(String vendorId, bool active) async {
    final String id = vendorId.trim();
    if (id.isEmpty) {
      return 'Set vendor store ID first (Products → store ID).';
    }
    if (_auth.currentUser == null) {
      return 'Sign in first.';
    }
    try {
      final bool allowed = await _isAuthorizedVendorId(id);
      if (!allowed) {
        return 'You are not allowed to update this store.';
      }
      final DocumentSnapshot<Map<String, dynamic>> snap =
          await _vendors.doc(id).get();
      final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
      final String? approval = data['approvalStatus'] as String?;
      if (isApprovalBlocking(approval)) {
        return 'Your shop must be approved before going live.';
      }
      final OpeningHours hours = parseOpeningHours(data['openingHours']);
      final DateTime boundary = nextScheduleBoundary(DateTime.now(), hours);
      await _vendors.doc(id).set(<String, dynamic>{
        'active': active,
        'openOverrideUntil': Timestamp.fromDate(boundary.toUtc()),
      }, SetOptions(merge: true));
      return null;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not update store.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not update store.');
    }
  }

  /// Align `active` with opening hours when no manual override is in effect.
  ///
  /// Called on dashboard/settings load so vendors do not wait for the scheduler.
  Future<String?> syncVendorOpenStatusFromSchedule(String vendorId) async {
    final String id = vendorId.trim();
    if (id.isEmpty) {
      return null;
    }
    if (_auth.currentUser == null) {
      return null;
    }
    try {
      final bool allowed = await _isAuthorizedVendorId(id);
      if (!allowed) {
        return null;
      }
      final DocumentReference<Map<String, dynamic>> ref = _vendors.doc(id);
      final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
      if (!snap.exists || snap.data() == null) {
        return null;
      }
      final Map<String, dynamic> data = snap.data()!;
      final DateTime? overrideUntil = _readTimestamp(data['openOverrideUntil']);
      final SyncVendorOpenResult result = syncVendorOpenStatus(
        now: DateTime.now(),
        approvalStatus: data['approvalStatus'] as String?,
        active: data['active'] as bool?,
        openingHours: data['openingHours'],
        openOverrideUntil: overrideUntil,
      );
      if (!result.changed) {
        return null;
      }
      final Map<String, dynamic> patch = <String, dynamic>{
        'active': result.active,
      };
      if (result.clearOverride) {
        patch['openOverrideUntil'] = FieldValue.delete();
      }
      await ref.set(patch, SetOptions(merge: true));
      return null;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not sync store hours.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not sync store hours.');
    }
  }

  DateTime? _readTimestamp(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  /// Live orders for this store (newest first). Empty stream if [vendorId] blank or not signed in.
  Stream<VendorOrderBoard> watchOrderBoard(String vendorId) {
    final String id = vendorId.trim();
    if (id.isEmpty || _auth.currentUser == null) {
      return Stream<VendorOrderBoard>.value(VendorOrderBoard.empty);
    }
    final DateTime lookbackStart = DateTime.now().subtract(const Duration(days: 30));
    final Timestamp lookbackTimestamp = Timestamp.fromDate(lookbackStart);
    return _orders
        .where('vendorId', isEqualTo: id)
        .where('createdAt', isGreaterThanOrEqualTo: lookbackTimestamp)
        .orderBy('createdAt', descending: true)
        .limit(1000)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
          return _mapOrderBoardSnapshot(snap);
        });
  }

  VendorOrderBoard _mapOrderBoardSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
          final bool isTruncated = snap.docs.length >= 1000;
          final List<VendorPendingOrder> incoming = <VendorPendingOrder>[];
          final List<VendorPendingOrder> kitchen = <VendorPendingOrder>[];
          final List<VendorPendingOrder> ready = <VendorPendingOrder>[];
          final List<VendorPendingOrder> outForDelivery =
              <VendorPendingOrder>[];
          final List<VendorPendingOrder> completed = <VendorPendingOrder>[];
          final List<VendorPendingOrder> cancelled = <VendorPendingOrder>[];
          final List<VendorPendingOrder> all = <VendorPendingOrder>[];
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snap.docs) {
            final VendorPendingOrder o = VendorPendingOrder.fromFirestore(
              doc.id,
              doc.data(),
            );
            all.add(o);
            final String s = o.statusKey;
            if (VendorOrderStatus.isIncoming(s)) {
              incoming.add(o);
            } else if (VendorOrderStatus.isKitchen(s)) {
              kitchen.add(o);
            } else if (VendorOrderStatus.isReadyForPickup(s)) {
              ready.add(o);
            } else if (VendorOrderStatus.isWithRider(s)) {
              outForDelivery.add(o);
            } else if (VendorOrderStatus.isCompleted(s)) {
              completed.add(o);
            } else if (VendorOrderStatus.isCancelled(s)) {
              cancelled.add(o);
            }
          }
          final VendorSalesSummary salesSummary =
              VendorSalesAggregator.fromOrders(all, now: DateTime.now());
          return VendorOrderBoard(
            incoming: incoming,
            kitchen: kitchen,
            readyForPickup: ready,
            outForDelivery: outForDelivery,
            completed: completed,
            cancelled: cancelled,
            salesSummary: salesSummary,
            isTruncated: isTruncated,
          );
  }

  Future<String?> updateOrderStatus({
    required String orderId,
    required String nextStatus,
  }) async {
    if (_auth.currentUser == null) {
      return 'Sign in to update orders.';
    }
    final String normalizedStatus = nextStatus.trim().toLowerCase();
    if (!VendorOrderStatus.isKnown(normalizedStatus)) {
      return 'Invalid order status.';
    }
    String priorStatus = '';
    String vendorId = '';
    try {
      final bool allowed = await _canMutateOrder(orderId);
      if (!allowed) {
        return 'You are not allowed to update this order.';
      }
      final String? txError = await _firestore.runTransaction<String?>((
        Transaction tx,
      ) async {
        final DocumentReference<Map<String, dynamic>> orderRef = _orders.doc(
          orderId,
        );
        final DocumentSnapshot<Map<String, dynamic>> orderSnap = await tx.get(
          orderRef,
        );
        if (!orderSnap.exists) {
          return 'This order no longer exists.';
        }
        final Map<String, dynamic> data = orderSnap.data() ?? <String, dynamic>{};
        final String currentStatus =
            (data['status'] as String?)?.trim().toLowerCase() ?? '';
        final String fulfillmentMode =
            (data['fulfillmentMode'] as String?)?.trim() ?? 'delivery';
        final String assigned =
            (data['assignedRiderId'] as String?)?.trim() ??
            (data['riderId'] as String?)?.trim() ??
            '';
        // Re-check the transition against the status read inside this
        // transaction (not a stale pre-fetch) so a concurrent write —
        // e.g. the backend's stale-order auto-cancel sweep, or a rider
        // claiming the job — can't be silently overwritten by a vendor
        // action that read the order a moment earlier.
        if (!VendorOrderStatus.canVendorTransition(
          from: currentStatus,
          to: normalizedStatus,
          fulfillmentMode: fulfillmentMode,
          hasAssignedRider: assigned.isNotEmpty,
        )) {
          return 'Invalid order status transition.';
        }
        final Map<String, dynamic> patch = <String, dynamic>{
          'status': normalizedStatus,
          'vendorStatusUpdatedAt': FieldValue.serverTimestamp(),
        };
        patch['openForRiders'] = VendorOrderStatus.opensRiderMatching(
          status: normalizedStatus,
          fulfillmentMode: fulfillmentMode,
        );
        tx.update(orderRef, patch);
        priorStatus = currentStatus;
        vendorId = (data['vendorId'] as String?)?.trim() ?? '';
        return null;
      });
      if (txError == null &&
          priorStatus == 'placed' &&
          normalizedStatus != 'placed') {
        // The vendor confirmed this order from the board rather than by
        // tapping the reminder notification itself — clear any pending
        // accept-reminder so it doesn't linger unread in the inbox.
        await _clearOrderReminderNotifications(
          vendorId: vendorId,
          orderId: orderId,
        );
      }
      return txError;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not update order.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not update order.');
    }
  }

  Future<String?> rejectOrder({required String orderId}) async {
    if (_auth.currentUser == null) {
      return 'Sign in to update orders.';
    }
    String priorStatus = '';
    String vendorId = '';
    try {
      final bool allowed = await _canMutateOrder(orderId);
      if (!allowed) {
        return 'You are not allowed to update this order.';
      }
      final String? txError = await _firestore.runTransaction<String?>((
        Transaction tx,
      ) async {
        final DocumentReference<Map<String, dynamic>> orderRef = _orders.doc(
          orderId,
        );
        final DocumentSnapshot<Map<String, dynamic>> orderSnap = await tx.get(
          orderRef,
        );
        if (!orderSnap.exists) {
          return 'This order no longer exists.';
        }
        final Map<String, dynamic> data = orderSnap.data() ?? <String, dynamic>{};
        final String currentStatus =
            (data['status'] as String?)?.trim().toLowerCase() ?? '';
        final String fulfillmentMode =
            (data['fulfillmentMode'] as String?)?.trim() ?? 'delivery';
        final String assigned =
            (data['assignedRiderId'] as String?)?.trim() ??
            (data['riderId'] as String?)?.trim() ??
            '';
        if (!VendorOrderStatus.canVendorTransition(
          from: currentStatus,
          to: 'cancelled',
          fulfillmentMode: fulfillmentMode,
          hasAssignedRider: assigned.isNotEmpty,
        )) {
          return 'This order can no longer be rejected.';
        }
        tx.update(orderRef, <String, dynamic>{
          'status': 'cancelled',
          'openForRiders': false,
          'cancelledBy': 'vendor',
          'cancellationReason': 'vendor_rejected',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        priorStatus = currentStatus;
        vendorId = (data['vendorId'] as String?)?.trim() ?? '';
        return null;
      });
      if (txError == null && priorStatus == 'placed') {
        await _clearOrderReminderNotifications(
          vendorId: vendorId,
          orderId: orderId,
        );
      }
      return txError;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not reject order.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not reject order.');
    }
  }

  Future<String?> syncVendorStoreIdToProfile(String vendorStoreId) async {
    final User? u = _auth.currentUser;
    if (u == null) {
      return 'Not signed in.';
    }
    final String v = vendorStoreId.trim();
    if (v.isEmpty) {
      return 'Store ID is empty.';
    }
    try {
      await _firestore.collection(FirebaseCollections.vendors).doc(u.uid).set(
        <String, dynamic>{'vendorStoreId': v},
        SetOptions(merge: true),
      );
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        return 'Your shop profile could not be updated. Please contact support.';
      }
      return userFacingError(e, fallback: 'Could not save profile.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not save profile.');
    }
  }
}
