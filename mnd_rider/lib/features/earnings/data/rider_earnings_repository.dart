import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_aggregate.dart';
import 'package:mnd_rider/features/earnings/domain/rider_transaction.dart';
import 'package:mnd_rider/features/earnings/domain/rider_wallet.dart';
import 'package:mnd_rider/features/earnings/domain/rider_withdrawal.dart';

final Provider<RiderEarningsRepository> riderEarningsRepositoryProvider =
    Provider<RiderEarningsRepository>((Ref ref) {
  return RiderEarningsRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

/// Firestore earnings layer for riders.
///
/// Structure:
/// - `riders/{riderId}/wallet/summary` — balance & lifetime totals
/// - `riders/{riderId}/earnings_aggregates/{periodKey}` — daily/weekly/monthly totals
/// - `riders/{riderId}/transactions/{id}` — ledger (delivery credits, withdrawals)
/// - `riders/{riderId}/withdrawals/{id}` — payout requests
class RiderEarningsRepository {
  RiderEarningsRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _auth = auth,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  static const double minWithdrawalLkr = 500;
  static const double maxWithdrawalLkr = 500000;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _riderRef(String riderId) =>
      _firestore.collection(FirebaseCollections.riders).doc(riderId);

  DocumentReference<Map<String, dynamic>> _walletRef(String riderId) =>
      _riderRef(riderId)
          .collection(FirebaseCollections.riderWallet)
          .doc(FirebaseCollections.riderWalletSummaryId);

  CollectionReference<Map<String, dynamic>> _transactionsRef(String riderId) =>
      _riderRef(riderId).collection(FirebaseCollections.riderTransactions);

  CollectionReference<Map<String, dynamic>> _withdrawalsRef(String riderId) =>
      _riderRef(riderId).collection(FirebaseCollections.riderWithdrawals);

  CollectionReference<Map<String, dynamic>> _earningsAggregatesRef(
    String riderId,
  ) =>
      _riderRef(riderId).collection(FirebaseCollections.riderEarningsAggregates);

  /// Watches one daily/weekly/monthly aggregate doc (see
  /// [RiderEarningsPeriodKeys]), written server-side by
  /// `onOrderDeliveredCreditRider`/`onTripCompletedCreditRider`. This is the
  /// authoritative, commission-adjusted total covering both deliveries and
  /// passenger rides — null while the rider has no completed job in that
  /// period yet.
  Stream<RiderEarningsAggregate?> watchEarningsAggregate(String periodKey) {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<RiderEarningsAggregate?>.value(null);
    }
    return _earningsAggregatesRef(uid).doc(periodKey).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snap) {
        final Map<String, dynamic>? data = snap.data();
        if (data == null) {
          return null;
        }
        return RiderEarningsAggregate.fromDoc(snap.id, data);
      },
    );
  }

  Stream<RiderWallet> watchWallet() {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<RiderWallet>.value(const RiderWallet.empty());
    }
    return _walletRef(uid).snapshots().map(
          (DocumentSnapshot<Map<String, dynamic>> snap) =>
              RiderWallet.fromMap(snap.data()),
        );
  }

  Stream<List<RiderTransaction>> watchTransactions({int limit = 40}) {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<List<RiderTransaction>>.value(const <RiderTransaction>[]);
    }
    return _transactionsRef(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    RiderTransaction.fromDoc(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  Stream<List<RiderWithdrawal>> watchWithdrawals({int limit = 20}) {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<List<RiderWithdrawal>>.value(const <RiderWithdrawal>[]);
    }
    return _withdrawalsRef(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    RiderWithdrawal.fromDoc(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  /// Server-validated withdrawal. Balance verification and the wallet debit
  /// happen inside the `requestRiderWithdrawal` Cloud Function (Admin SDK), so
  /// the client can no longer bypass the balance check.
  Future<String?> requestWithdrawal({
    required double amountLkr,
    required String payoutMethod,
    required String payoutAccount,
    String? note,
  }) async {
    if (_uid == null) {
      return 'Not signed in.';
    }
    final int amount = amountLkr.round();
    if (amount < minWithdrawalLkr) {
      return 'Minimum withdrawal is Rs. ${minWithdrawalLkr.round()}.';
    }
    if (amount > maxWithdrawalLkr) {
      return 'Maximum withdrawal is Rs. ${maxWithdrawalLkr.round()}.';
    }

    final String account = payoutAccount.trim();
    if (account.length < 4) {
      return 'Enter a valid payout account.';
    }

    try {
      await _functions
          .httpsCallable('requestRiderWithdrawal')
          .call<dynamic>(<String, dynamic>{
        'amountLkr': amount,
        'payoutMethod': payoutMethod.trim().toLowerCase(),
        'payoutAccount': account,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Withdrawal request failed.';
    } catch (e) {
      return userFacingError(e, fallback: 'Withdrawal request failed.');
    }
  }
}
