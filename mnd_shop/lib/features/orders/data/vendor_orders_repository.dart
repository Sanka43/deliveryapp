import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_sales_aggregator.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_sales_summary.dart';

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
    required this.salesSummary,
  });

  final List<VendorPendingOrder> incoming;
  final List<VendorPendingOrder> kitchen;
  final List<VendorPendingOrder> readyForPickup;
  /// Reserved for a future `shipping` / out-for-delivery status; empty with current schema.
  final List<VendorPendingOrder> outForDelivery;
  final List<VendorPendingOrder> completed;
  final VendorSalesSummary salesSummary;

  static const VendorOrderBoard empty = VendorOrderBoard(
    incoming: <VendorPendingOrder>[],
    kitchen: <VendorPendingOrder>[],
    readyForPickup: <VendorPendingOrder>[],
    outForDelivery: <VendorPendingOrder>[],
    completed: <VendorPendingOrder>[],
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
  })  : _firestore = firestore,
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
    final DocumentSnapshot<Map<String, dynamic>> snap = await _vendors.doc(id).get();
    final String owner = (snap.data()?['uid'] as String?)?.trim() ?? '';
    return snap.exists && owner == uid;
  }

  Future<bool> _canMutateOrder(String orderId) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap = await _orders.doc(orderId).get();
    if (!snap.exists) {
      return false;
    }
    final String vendorId = (snap.data()?['vendorId'] as String?)?.trim() ?? '';
    return _isAuthorizedVendorId(vendorId);
  }

  /// Whether the store is accepting orders (`active != false`). Defaults to true if doc missing.
  Stream<bool> watchVendorActive(String vendorId) {
    final String id = vendorId.trim();
    if (id.isEmpty) {
      return Stream<bool>.value(true);
    }
    return _vendors.doc(id).snapshots().map((DocumentSnapshot<Map<String, dynamic>> s) {
      if (!s.exists || s.data() == null) {
        return true;
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
      await _vendors.doc(id).set(
        <String, dynamic>{'active': active},
        SetOptions(merge: true),
      );
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not update store.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Live orders for this store (newest first). Empty stream if [vendorId] blank or not signed in.
  Stream<VendorOrderBoard> watchOrderBoard(String vendorId) {
    final String id = vendorId.trim();
    if (id.isEmpty || _auth.currentUser == null) {
      return Stream<VendorOrderBoard>.value(VendorOrderBoard.empty);
    }
    return _orders
        .where('vendorId', isEqualTo: id)
        .orderBy('createdAt', descending: true)
        .limit(150)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      final List<VendorPendingOrder> incoming = <VendorPendingOrder>[];
      final List<VendorPendingOrder> kitchen = <VendorPendingOrder>[];
      final List<VendorPendingOrder> ready = <VendorPendingOrder>[];
      final List<VendorPendingOrder> outForDelivery = <VendorPendingOrder>[];
      final List<VendorPendingOrder> completed = <VendorPendingOrder>[];
      final List<VendorPendingOrder> all = <VendorPendingOrder>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
        final VendorPendingOrder o = VendorPendingOrder.fromFirestore(doc.id, doc.data());
        all.add(o);
        final String s = o.statusKey.toLowerCase();
        if (s == 'placed') {
          incoming.add(o);
        } else if (s == 'confirmed' || s == 'preparing') {
          kitchen.add(o);
        } else if (s == 'ready') {
          ready.add(o);
        } else if (s == 'completed') {
          completed.add(o);
        }
      }
      final VendorSalesSummary salesSummary = VendorSalesAggregator.fromOrders(
        all,
        now: DateTime.now(),
      );
      return VendorOrderBoard(
        incoming: incoming,
        kitchen: kitchen,
        readyForPickup: ready,
        outForDelivery: outForDelivery,
        completed: completed,
        salesSummary: salesSummary,
      );
    });
  }

  Future<String?> updateOrderStatus({
    required String orderId,
    required String nextStatus,
  }) async {
    if (_auth.currentUser == null) {
      return 'Sign in to update orders.';
    }
    final String normalizedStatus = nextStatus.trim().toLowerCase();
    const Set<String> allowedStatuses = <String>{'placed', 'confirmed', 'preparing', 'ready', 'completed', 'cancelled'};
    if (!allowedStatuses.contains(normalizedStatus)) {
      return 'Invalid order status.';
    }
    try {
      final bool allowed = await _canMutateOrder(orderId);
      if (!allowed) {
        return 'You are not allowed to update this order.';
      }
      final Map<String, dynamic> patch = <String, dynamic>{
        'status': normalizedStatus,
        'vendorStatusUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (normalizedStatus == 'ready') {
        patch['openForRiders'] = true;
      } else if (normalizedStatus == 'cancelled') {
        patch['openForRiders'] = false;
      } else if (normalizedStatus != 'ready') {
        patch['openForRiders'] = false;
      }
      await _orders.doc(orderId).update(patch);
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not update order.';
    } catch (e) {
      return 'Could not update order.';
    }
  }

  Future<String?> rejectOrder({required String orderId}) async {
    if (_auth.currentUser == null) {
      return 'Sign in to update orders.';
    }
    try {
      final bool allowed = await _canMutateOrder(orderId);
      if (!allowed) {
        return 'You are not allowed to update this order.';
      }
      await _orders.doc(orderId).update(<String, dynamic>{
        'status': 'cancelled',
        'openForRiders': false,
        'cancelledBy': 'vendor',
        'cancellationReason': 'vendor_rejected',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not reject order.';
    } catch (e) {
      return 'Could not reject order.';
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
        return 'Vendor doc missing in Firestore. Create vendors/${u.uid} or sync store ID (admin).';
      }
      return e.message ?? 'Could not save profile.';
    } catch (e) {
      return e.toString();
    }
  }
}
