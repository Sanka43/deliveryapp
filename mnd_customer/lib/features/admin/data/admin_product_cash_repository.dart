import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';

final Provider<FirebaseFunctions> firebaseFunctionsProvider =
    Provider<FirebaseFunctions>(
  (Ref ref) => FirebaseFunctions.instanceFor(region: 'asia-south1'),
);

final Provider<AdminProductCashRepository> adminProductCashRepositoryProvider =
    Provider<AdminProductCashRepository>((Ref ref) {
  return AdminProductCashRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

class AdminProductCashRow {
  const AdminProductCashRow({
    required this.id,
    required this.productCashStatus,
    required this.productCashLkr,
    required this.storeName,
    required this.vendorId,
    required this.riderId,
    this.trackingNumber,
    this.deliveredAt,
  });

  final String id;
  final String productCashStatus;
  final int productCashLkr;
  final String storeName;
  final String vendorId;
  final String riderId;
  final String? trackingNumber;
  final DateTime? deliveredAt;

  String get referenceForDisplay {
    final String? t = trackingNumber?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return id;
  }

  factory AdminProductCashRow.fromDoc(String id, Map<String, dynamic> data) {
    final dynamic deliveredRaw = data['deliveredAt'];
    final DateTime? deliveredAt =
        deliveredRaw is Timestamp ? deliveredRaw.toDate() : null;
    final String? tn = (data['trackingNumber'] as String?)?.trim();
    final int cash = data['productCashLkr'] is int
        ? data['productCashLkr'] as int
        : (data['productCashLkr'] is num
            ? (data['productCashLkr'] as num).round()
            : int.tryParse('${data['productCashLkr']}') ?? 0);
    return AdminProductCashRow(
      id: id,
      productCashStatus:
          (data['productCashStatus'] as String?)?.trim().toLowerCase() ?? '',
      productCashLkr: cash,
      storeName: (data['storeName'] as String?)?.trim() ?? 'Store',
      vendorId: (data['vendorId'] as String?)?.trim() ?? '',
      riderId: (data['productCashRiderId'] as String?)?.trim() ??
          (data['riderId'] as String?)?.trim() ??
          (data['assignedRiderId'] as String?)?.trim() ??
          '',
      trackingNumber: (tn == null || tn.isEmpty) ? null : tn,
      deliveredAt: deliveredAt,
    );
  }
}

class AdminProductCashRepository {
  AdminProductCashRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _auth = auth,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Stream<List<AdminProductCashRow>> watchByStatus(String status, {int limit = 50}) {
    if (_auth.currentUser == null) {
      return Stream<List<AdminProductCashRow>>.value(const <AdminProductCashRow>[]);
    }
    final String normalized = status.trim().toLowerCase();
    return _firestore
        .collection(FirebaseCollections.orders)
        .where('productCashStatus', isEqualTo: normalized)
        .orderBy('deliveredAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    AdminProductCashRow.fromDoc(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  Future<String?> markRemitted(String orderId) async {
    try {
      await _functions.httpsCallable('adminMarkProductCashRemitted').call(
        <String, dynamic>{'orderId': orderId.trim()},
      );
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : 'Could not mark remitted.';
    } catch (_) {
      return 'Could not mark remitted.';
    }
  }

  Future<String?> markSettledToShop(String orderId) async {
    try {
      await _functions
          .httpsCallable('adminMarkProductCashSettledToShop')
          .call(<String, dynamic>{'orderId': orderId.trim()});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : 'Could not mark settled.';
    } catch (_) {
      return 'Could not mark settled.';
    }
  }
}
