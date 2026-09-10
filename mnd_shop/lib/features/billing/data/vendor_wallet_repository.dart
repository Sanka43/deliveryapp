import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/billing/domain/vendor_payout.dart';
import 'package:mnd_shop/features/billing/domain/vendor_wallet.dart';

final Provider<VendorWalletRepository> vendorWalletRepositoryProvider =
    Provider<VendorWalletRepository>((Ref ref) {
  return VendorWalletRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Wallet balance + payout requests. Balance and history are server-written
/// only (see firestore.rules) — this repository never writes them directly,
/// it only reads and calls `requestVendorPayout`.
class VendorWalletRepository {
  VendorWalletRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _functions = functions,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _vendorDoc(String vendorId) =>
      _firestore.collection(FirebaseCollections.vendors).doc(vendorId.trim());

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
    final DocumentSnapshot<Map<String, dynamic>> snap = await _vendorDoc(id).get();
    final String owner = (snap.data()?['uid'] as String?)?.trim() ?? '';
    return snap.exists && owner == uid;
  }

  Stream<VendorWallet> watchWallet(String vendorId) async* {
    final String id = vendorId.trim();
    if (id.isEmpty || !await _isAuthorizedVendorId(id)) {
      yield VendorWallet.zero;
      return;
    }
    yield* _vendorDoc(id)
        .collection(FirebaseCollections.vendorWallet)
        .doc(FirebaseCollections.vendorWalletSummaryDocId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> s) =>
            VendorWallet.fromFirestore(s.data()));
  }

  Stream<List<VendorPayout>> watchPayouts(String vendorId) async* {
    final String id = vendorId.trim();
    if (id.isEmpty || !await _isAuthorizedVendorId(id)) {
      yield const <VendorPayout>[];
      return;
    }
    yield* _vendorDoc(id)
        .collection(FirebaseCollections.vendorPayouts)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      return snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              VendorPayout.fromFirestore(d.id, d.data()))
          .toList(growable: false);
    });
  }

  /// Returns `null` on success, or a user-facing error message.
  Future<String?> requestPayout({
    required double amountLkr,
    required String payoutMethod,
    required String payoutAccount,
    String note = '',
  }) async {
    if (_auth.currentUser == null) {
      return 'Sign in to request a payout.';
    }
    try {
      await _functions.httpsCallable('requestVendorPayout').call(<String, dynamic>{
        'amountLkr': amountLkr.round(),
        'payoutMethod': payoutMethod.trim().toLowerCase(),
        'payoutAccount': payoutAccount.trim(),
        if (note.trim().isNotEmpty) 'note': note.trim(),
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return userFacingError(e, fallback: 'Could not submit payout request.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not submit payout request.');
    }
  }
}
