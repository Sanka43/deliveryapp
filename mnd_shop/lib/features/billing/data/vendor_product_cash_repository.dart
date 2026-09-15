import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';

final Provider<VendorProductCashRepository> vendorProductCashRepositoryProvider =
    Provider<VendorProductCashRepository>((Ref ref) {
  return VendorProductCashRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// One status bucket's live total for a shop's cash-on-delivery ledger —
/// see VendorProductCashSummary for what the four statuses mean.
typedef VendorProductCashBucket = ({double totalLkr, int count});

/// Reads (never writes) the same `orders.productCashStatus` ledger the
/// admin panel's "Shop cash" page settles — see productCash.ts. Balance and
/// history are server-authoritative; this repository only aggregates.
class VendorProductCashRepository {
  VendorProductCashRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _firestore.collection(FirebaseCollections.vendors).doc(id).get();
    final String owner = (snap.data()?['uid'] as String?)?.trim() ?? '';
    return snap.exists && owner == uid;
  }

  static double _amountOf(Map<String, dynamic> data) {
    final Object? raw = data['productCashLkr'];
    return raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
  }

  /// Live sum + count of orders at [status] for [vendorId]. Two pure-equality
  /// queries, not one — order docs identify their shop under `vendorId` on
  /// current writes but some carry only the legacy `vendorStoreId` (same
  /// dual-field fallback `vendorIdOf()` in functions/src/vendorEarnings.ts
  /// and the admin panel's Shop cash page already account for); querying
  /// `vendorId` alone silently undercounts those. Results are merged by doc
  /// id so an order carrying both fields set to the same value isn't
  /// double-counted. Neither query has an `orderBy` (only a total is
  /// needed, not a sorted list), so neither needs a composite Firestore
  /// index beyond the automatic per-field ones.
  Stream<VendorProductCashBucket> watchStatus(String vendorId, String status) async* {
    final String id = vendorId.trim();
    if (id.isEmpty || !await _isAuthorizedVendorId(id)) {
      yield (totalLkr: 0, count: 0);
      return;
    }

    final StreamController<VendorProductCashBucket> controller = StreamController<VendorProductCashBucket>();
    Map<String, double> byVendorId = <String, double>{};
    Map<String, double> byVendorStoreId = <String, double>{};
    bool haveVendorId = false;
    bool haveVendorStoreId = false;

    void emitCombined() {
      if (!haveVendorId || !haveVendorStoreId) {
        return;
      }
      final Map<String, double> merged = <String, double>{...byVendorStoreId, ...byVendorId};
      double total = 0;
      for (final double v in merged.values) {
        total += v;
      }
      if (!controller.isClosed) {
        controller.add((totalLkr: total, count: merged.length));
      }
    }

    final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subByVendorId = _firestore
        .collection(FirebaseCollections.orders)
        .where('vendorId', isEqualTo: id)
        .where('productCashStatus', isEqualTo: status)
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snap) {
        byVendorId = <String, double>{
          for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) d.id: _amountOf(d.data()),
        };
        haveVendorId = true;
        emitCombined();
      },
      onError: controller.addError,
    );

    final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subByVendorStoreId = _firestore
        .collection(FirebaseCollections.orders)
        .where('vendorStoreId', isEqualTo: id)
        .where('productCashStatus', isEqualTo: status)
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snap) {
        byVendorStoreId = <String, double>{
          for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) d.id: _amountOf(d.data()),
        };
        haveVendorStoreId = true;
        emitCombined();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await subByVendorId.cancel();
      await subByVendorStoreId.cancel();
    };

    yield* controller.stream;
  }
}
