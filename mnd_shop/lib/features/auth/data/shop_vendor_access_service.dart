import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/auth/domain/vendor_deletion_status.dart';

enum ShopVendorAccessResult {
  allowed,
  customerAccount,
  riderAccount,
  deletionBlocked,
}

/// Post-login access check for the shop app.
class ShopVendorAccessService {
  ShopVendorAccessService({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<ShopVendorAccessResult> evaluate(User user) async {
    final String uid = user.uid.trim();
    if (uid.isEmpty) {
      return ShopVendorAccessResult.customerAccount;
    }

    final DocumentSnapshot<Map<String, dynamic>> vendorSnap = await _firestore
        .collection(FirebaseCollections.vendors)
        .doc(uid)
        .get();
    final Map<String, dynamic>? vendorData = vendorSnap.data();
    if (vendorSnap.exists && vendorData?.isNotEmpty == true) {
      if (VendorDeletionStatus.blocksAppAccess(vendorData)) {
        return ShopVendorAccessResult.deletionBlocked;
      }
      return ShopVendorAccessResult.allowed;
    }

    final DocumentSnapshot<Map<String, dynamic>> customerSnap = await _firestore
        .collection(FirebaseCollections.customers)
        .doc(uid)
        .get();
    final String role =
        (customerSnap.data()?['role'] as String?)?.trim().toLowerCase() ?? '';
    if (customerSnap.exists && role == 'customer') {
      return ShopVendorAccessResult.customerAccount;
    }
    if (customerSnap.exists && role == 'rider') {
      return ShopVendorAccessResult.riderAccount;
    }

    final DocumentSnapshot<Map<String, dynamic>> riderSnap = await _firestore
        .collection(FirebaseCollections.riders)
        .doc(uid)
        .get();
    if (riderSnap.exists) {
      return ShopVendorAccessResult.riderAccount;
    }

    // New shop owner without profiles yet — allow registration gate.
    return ShopVendorAccessResult.allowed;
  }
}

final Provider<ShopVendorAccessService> shopVendorAccessServiceProvider =
    Provider<ShopVendorAccessService>((Ref ref) {
  return ShopVendorAccessService(firestore: ref.watch(firestoreProvider));
});
