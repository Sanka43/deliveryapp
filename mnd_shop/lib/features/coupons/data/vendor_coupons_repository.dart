import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/coupons/domain/vendor_coupon.dart';

final Provider<VendorCouponsRepository> vendorCouponsRepositoryProvider =
    Provider<VendorCouponsRepository>((Ref ref) {
  return VendorCouponsRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Vendor-scoped coupons under top-level `coupons/{code}`. Creation always
/// goes through the `requestVendorCoupon` callable (server validates and
/// gates on shop approval); this repository otherwise only reads the
/// vendor's own coupons and toggles `active` — the one field firestore.rules
/// lets a vendor write directly on their own coupon doc.
class VendorCouponsRepository {
  VendorCouponsRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _functions = functions,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _coupons =>
      _firestore.collection(FirebaseCollections.coupons);

  /// No `orderBy` — a single-field equality query needs no composite index,
  /// and a shop's own coupon list is small enough to sort client-side.
  Stream<List<VendorCoupon>> watchCoupons(String vendorId) {
    final String id = vendorId.trim();
    if (id.isEmpty) {
      return Stream<List<VendorCoupon>>.value(const <VendorCoupon>[]);
    }
    return _coupons.where('storeId', isEqualTo: id).snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snap) {
        final List<VendorCoupon> list = snap.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                VendorCoupon.fromFirestore(d.id, d.data()))
            .toList();
        list.sort((VendorCoupon a, VendorCoupon b) {
          final DateTime ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
        return list;
      },
    );
  }

  /// Returns `null` on success, or a user-facing error message.
  Future<String?> requestCoupon({
    required String code,
    required VendorCouponDiscountType discountType,
    required int value,
    required DateTime expiresAt,
    int? minSubtotalLkr,
    int? maxDiscountLkr,
    int? maxUses,
    int? perCustomerLimit,
  }) async {
    if (_auth.currentUser == null) {
      return 'Sign in to create a coupon.';
    }
    try {
      await _functions.httpsCallable('requestVendorCoupon').call(<String, dynamic>{
        'code': code.trim(),
        'discountType':
            discountType == VendorCouponDiscountType.percent ? 'percent' : 'flat',
        'value': value,
        'expiresAtMs': expiresAt.millisecondsSinceEpoch,
        'minSubtotalLkr': ?minSubtotalLkr,
        'maxDiscountLkr': ?maxDiscountLkr,
        'maxUses': ?maxUses,
        'perCustomerLimit': ?perCustomerLimit,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return userFacingError(e, fallback: 'Could not create coupon.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not create coupon.');
    }
  }

  /// Pause/resume a coupon the vendor already owns — the only field
  /// firestore.rules lets a non-admin write on a coupon doc.
  Future<String?> setActive(String code, bool active) async {
    try {
      await _coupons.doc(code).update(<String, dynamic>{'active': active});
      return null;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not update coupon.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not update coupon.');
    }
  }
}
