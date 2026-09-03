import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/features/earnings/data/rider_cash_repository.dart';
import 'package:mnd_rider/features/earnings/domain/rider_transaction.dart';
import 'package:mnd_rider/features/earnings/domain/rider_withdrawal.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/reports/domain/rider_report_data.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';

final Provider<RiderReportRepository> riderReportRepositoryProvider =
    Provider<RiderReportRepository>((Ref ref) {
  return RiderReportRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// One-shot, date-range-bound reads for the report screen. Kept separate from
/// the feature repositories' live streams (which cap at a fixed page size)
/// so a report always covers the exact range the rider picked, however far
/// back it goes.
class RiderReportRepository {
  RiderReportRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<RiderReportData> fetchReport({
    required DateTime start,
    required DateTime end,
  }) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return RiderReportData.empty(start: start, end: end);
    }

    final Timestamp startTs = Timestamp.fromDate(start);
    final Timestamp endTs = Timestamp.fromDate(end);

    final Future<List<RiderOrderDetail>> deliveriesFuture =
        _fetchDeliveries(uid, startTs, endTs);
    final Future<List<RiderPassengerTrip>> tripsFuture =
        _fetchTrips(uid, startTs, endTs);
    final Future<List<RiderTransaction>> transactionsFuture =
        _fetchTransactions(uid, startTs, endTs);
    final Future<List<RiderWithdrawal>> withdrawalsFuture =
        _fetchWithdrawals(uid, startTs, endTs);
    final Future<List<RiderCashEntry>> cashEntriesFuture =
        _fetchCashEntries(uid, startTs, endTs);
    final Future<List<RiderCashSettlement>> cashSettlementsFuture =
        _fetchCashSettlements(uid, startTs, endTs);

    return RiderReportData(
      start: start,
      end: end,
      deliveries: await deliveriesFuture,
      trips: await tripsFuture,
      transactions: await transactionsFuture,
      withdrawals: await withdrawalsFuture,
      cashEntries: await cashEntriesFuture,
      cashSettlements: await cashSettlementsFuture,
    );
  }

  Future<List<RiderOrderDetail>> _fetchDeliveries(
    String uid,
    Timestamp start,
    Timestamp end,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(FirebaseCollections.orders)
        .where('riderId', isEqualTo: uid)
        .where('status', isEqualTo: 'delivered')
        .orderBy('createdAt', descending: true)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .get();
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              RiderOrderDetail.fromDoc(d.id, d.data()),
        )
        .toList(growable: false);
  }

  Future<List<RiderPassengerTrip>> _fetchTrips(
    String uid,
    Timestamp start,
    Timestamp end,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(FirebaseCollections.trips)
        .where('assignedRiderId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .get();
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              RiderPassengerTrip.fromDoc(d.id, d.data()),
        )
        .where(
          (RiderPassengerTrip t) {
            final String s = t.status.toLowerCase();
            return s == 'completed' || s == 'cancelled';
          },
        )
        .toList(growable: false);
  }

  Future<List<RiderTransaction>> _fetchTransactions(
    String uid,
    Timestamp start,
    Timestamp end,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(FirebaseCollections.riders)
        .doc(uid)
        .collection(FirebaseCollections.riderTransactions)
        .orderBy('createdAt', descending: true)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .get();
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              RiderTransaction.fromDoc(d.id, d.data()),
        )
        .toList(growable: false);
  }

  Future<List<RiderWithdrawal>> _fetchWithdrawals(
    String uid,
    Timestamp start,
    Timestamp end,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(FirebaseCollections.riders)
        .doc(uid)
        .collection(FirebaseCollections.riderWithdrawals)
        .orderBy('createdAt', descending: true)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .get();
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              RiderWithdrawal.fromDoc(d.id, d.data()),
        )
        .toList(growable: false);
  }

  Future<List<RiderCashEntry>> _fetchCashEntries(
    String uid,
    Timestamp start,
    Timestamp end,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(FirebaseCollections.riders)
        .doc(uid)
        .collection(FirebaseCollections.riderCashLedger)
        .orderBy('createdAt', descending: true)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .get();
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              RiderCashEntry.fromDoc(d.id, d.data()),
        )
        .toList(growable: false);
  }

  Future<List<RiderCashSettlement>> _fetchCashSettlements(
    String uid,
    Timestamp start,
    Timestamp end,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection(FirebaseCollections.riders)
        .doc(uid)
        .collection(FirebaseCollections.riderCashSettlements)
        .orderBy('requestedAt', descending: true)
        .where('requestedAt', isGreaterThanOrEqualTo: start)
        .where('requestedAt', isLessThanOrEqualTo: end)
        .get();
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              RiderCashSettlement.fromDoc(d.id, d.data()),
        )
        .toList(growable: false);
  }
}
