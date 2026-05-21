import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_period_keys.dart';
import 'package:mnd_rider/features/earnings/domain/rider_transaction.dart';
import 'package:mnd_rider/features/earnings/domain/rider_wallet.dart';
import 'package:mnd_rider/features/earnings/domain/rider_withdrawal.dart';

final Provider<RiderEarningsRepository> riderEarningsRepositoryProvider =
    Provider<RiderEarningsRepository>((Ref ref) {
  return RiderEarningsRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
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
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const double minWithdrawalLkr = 500;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _riderRef(String riderId) =>
      _firestore.collection(FirebaseCollections.riders).doc(riderId);

  DocumentReference<Map<String, dynamic>> _walletRef(String riderId) =>
      _riderRef(riderId)
          .collection(FirebaseCollections.riderWallet)
          .doc(FirebaseCollections.riderWalletSummaryId);

  CollectionReference<Map<String, dynamic>> _aggregatesRef(String riderId) =>
      _riderRef(riderId).collection(FirebaseCollections.riderEarningsAggregates);

  CollectionReference<Map<String, dynamic>> _transactionsRef(String riderId) =>
      _riderRef(riderId).collection(FirebaseCollections.riderTransactions);

  CollectionReference<Map<String, dynamic>> _withdrawalsRef(String riderId) =>
      _riderRef(riderId).collection(FirebaseCollections.riderWithdrawals);

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

  /// Idempotent credit when a delivery is marked delivered.
  Future<String?> recordDeliveryEarning({
    required String orderId,
    required int amountLkr,
    required String storeName,
    String? trackingNumber,
    DateTime? completedAt,
  }) async {
    final String? uid = _uid;
    if (uid == null) {
      return 'Not signed in.';
    }
    if (amountLkr <= 0) {
      return null;
    }

    final String txnId = 'earning_$orderId';
    final DocumentReference<Map<String, dynamic>> txnRef =
        _transactionsRef(uid).doc(txnId);

    try {
      await _firestore.runTransaction((Transaction tx) async {
        final DocumentSnapshot<Map<String, dynamic>> existing =
            await tx.get(txnRef);
        if (existing.exists) {
          return;
        }

        final DateTime at = completedAt ?? DateTime.now();
        final double amount = amountLkr.toDouble();

        final DocumentReference<Map<String, dynamic>> walletRef =
            _walletRef(uid);
        final DocumentSnapshot<Map<String, dynamic>> walletSnap =
            await tx.get(walletRef);
        final RiderWallet wallet = RiderWallet.fromMap(walletSnap.data());

        tx.set(
          txnRef,
          <String, dynamic>{
            'type': 'delivery_earning',
            'status': 'completed',
            'amountLkr': amount,
            'orderId': orderId,
            'title': storeName,
            'subtitle': trackingNumber?.trim().isNotEmpty == true
                ? trackingNumber!.trim()
                : orderId,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );

        tx.set(
          walletRef,
          <String, dynamic>{
            'balanceLkr': wallet.balanceLkr + amount,
            'pendingWithdrawalLkr': wallet.pendingWithdrawalLkr,
            'lifetimeEarnedLkr': wallet.lifetimeEarnedLkr + amount,
            'lifetimeWithdrawnLkr': wallet.lifetimeWithdrawnLkr,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        _incrementAggregateTx(
          tx: tx,
          riderId: uid,
          periodKey: RiderEarningsPeriodKeys.dailyKey(at),
          periodType: 'daily',
          amount: amount,
        );
        _incrementAggregateTx(
          tx: tx,
          riderId: uid,
          periodKey: RiderEarningsPeriodKeys.weeklyKey(at),
          periodType: 'weekly',
          amount: amount,
        );
        _incrementAggregateTx(
          tx: tx,
          riderId: uid,
          periodKey: RiderEarningsPeriodKeys.monthlyKey(at),
          periodType: 'monthly',
          amount: amount,
        );
      });
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not record earnings.';
    } catch (e) {
      return e.toString();
    }
  }

  void _incrementAggregateTx({
    required Transaction tx,
    required String riderId,
    required String periodKey,
    required String periodType,
    required double amount,
  }) {
    final DocumentReference<Map<String, dynamic>> ref =
        _aggregatesRef(riderId).doc(periodKey);
    tx.set(
      ref,
      <String, dynamic>{
        'periodType': periodType,
        'totalLkr': FieldValue.increment(amount),
        'tripCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String?> requestWithdrawal({
    required double amountLkr,
    required String payoutMethod,
    required String payoutAccount,
    String? note,
  }) async {
    final String? uid = _uid;
    if (uid == null) {
      return 'Not signed in.';
    }
    if (amountLkr < minWithdrawalLkr) {
      return 'Minimum withdrawal is Rs. ${minWithdrawalLkr.round()}.';
    }

    final String account = payoutAccount.trim();
    if (account.length < 4) {
      return 'Enter a valid payout account.';
    }

    try {
      await _firestore.runTransaction((Transaction tx) async {
        final DocumentReference<Map<String, dynamic>> walletRef =
            _walletRef(uid);
        final DocumentSnapshot<Map<String, dynamic>> walletSnap =
            await tx.get(walletRef);
        final RiderWallet wallet = RiderWallet.fromMap(walletSnap.data());

        if (amountLkr > wallet.balanceLkr) {
          throw StateError('Insufficient balance.');
        }

        final DocumentReference<Map<String, dynamic>> withdrawalRef =
            _withdrawalsRef(uid).doc();
        final String withdrawalId = withdrawalRef.id;

        tx.set(withdrawalRef, <String, dynamic>{
          'amountLkr': amountLkr,
          'status': 'pending',
          'payoutMethod': payoutMethod.trim().toLowerCase(),
          'payoutAccount': account,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(
          _transactionsRef(uid).doc(),
          <String, dynamic>{
            'type': 'withdrawal',
            'status': 'pending',
            'amountLkr': -amountLkr,
            'withdrawalId': withdrawalId,
            'title': 'Withdrawal request',
            'subtitle': payoutMethod,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );

        tx.set(
          walletRef,
          <String, dynamic>{
            'balanceLkr': wallet.balanceLkr - amountLkr,
            'pendingWithdrawalLkr': wallet.pendingWithdrawalLkr + amountLkr,
            'lifetimeEarnedLkr': wallet.lifetimeEarnedLkr,
            'lifetimeWithdrawnLkr': wallet.lifetimeWithdrawnLkr,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
      return null;
    } on StateError catch (e) {
      return e.message;
    } on FirebaseException catch (e) {
      return e.message ?? 'Withdrawal request failed.';
    } catch (e) {
      return e.toString();
    }
  }
}
