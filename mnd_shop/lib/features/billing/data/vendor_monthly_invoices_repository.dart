import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/billing/domain/vendor_monthly_invoice.dart';

final Provider<VendorMonthlyInvoicesRepository>
    vendorMonthlyInvoicesRepositoryProvider =
    Provider<VendorMonthlyInvoicesRepository>((Ref ref) {
  return VendorMonthlyInvoicesRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Firestore: `vendors/{vendorId}/monthly_invoices/{yyyy-MM}` (admin-written).
class VendorMonthlyInvoicesRepository {
  VendorMonthlyInvoicesRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _invoices(String vendorId) {
    return _firestore
        .collection(FirebaseCollections.vendors)
        .doc(vendorId.trim())
        .collection(FirebaseCollections.vendorMonthlyInvoices);
  }

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
    return owner == uid;
  }

  Stream<List<VendorMonthlyInvoice>> watchInvoices(String vendorId) async* {
    final String id = vendorId.trim();
    if (id.isEmpty || !await _isAuthorizedVendorId(id)) {
      yield const <VendorMonthlyInvoice>[];
      return;
    }

    yield* _invoices(id).snapshots().map((QuerySnapshot<Map<String, dynamic>> snap) {
      final List<VendorMonthlyInvoice> list = snap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                VendorMonthlyInvoice.fromFirestore(d.id, d.data()),
          )
          .toList(growable: false);
      list.sort((VendorMonthlyInvoice a, VendorMonthlyInvoice b) {
        return b.monthKey.compareTo(a.monthKey);
      });
      return list;
    });
  }
}
