import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';

/// Default mirrored from `DEFAULT_MAX_CASH_IN_HAND_LKR` in
/// functions/src/riderCashLogic.ts — used only until `platform_config/fees`
/// loads, so the limit bar never renders against a nonsense ceiling.
const int kDefaultMaxCashInHandLkr = 7000;

final Provider<RiderCashRepository> riderCashRepositoryProvider =
    Provider<RiderCashRepository>((Ref ref) {
  return RiderCashRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

/// One collected-cash job on `riders/{uid}/cash_ledger`.
class RiderCashEntry {
  const RiderCashEntry({
    required this.id,
    required this.type,
    required this.status,
    required this.cashLkr,
    required this.owedLkr,
    required this.title,
    required this.subtitle,
    this.createdAt,
  });

  final String id;

  /// `ride_cash` or `order_cash`.
  final String type;

  /// `open` | `pending_settlement` | `settled`.
  final String status;

  /// Cash the rider took from the customer.
  final int cashLkr;

  /// Of that, what must reach admin.
  final int owedLkr;
  final String title;
  final String subtitle;
  final DateTime? createdAt;

  bool get isRide => type == 'ride_cash';
  bool get isWaitingOnAdmin => status == 'pending_settlement';

  factory RiderCashEntry.fromDoc(String id, Map<String, dynamic> data) {
    final dynamic created = data['createdAt'];
    return RiderCashEntry(
      id: id,
      type: (data['type'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim() ?? 'open',
      cashLkr: (data['cashLkr'] as num?)?.round() ?? 0,
      owedLkr: (data['owedLkr'] as num?)?.round() ?? 0,
      title: (data['title'] as String?)?.trim() ?? 'Collected cash',
      subtitle: (data['subtitle'] as String?)?.trim() ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// A handover the rider has asked admin to confirm.
class RiderCashSettlement {
  const RiderCashSettlement({
    required this.id,
    required this.amountLkr,
    required this.cashCoveredLkr,
    required this.status,
    required this.method,
    this.reference,
    this.requestedAt,
  });

  final String id;
  final int amountLkr;
  final int cashCoveredLkr;

  /// `requested` | `confirmed` | `rejected`.
  final String status;
  final String method;
  final String? reference;
  final DateTime? requestedAt;

  factory RiderCashSettlement.fromDoc(String id, Map<String, dynamic> data) {
    final dynamic requested = data['requestedAt'];
    final String? ref = (data['reference'] as String?)?.trim();
    return RiderCashSettlement(
      id: id,
      amountLkr: (data['amountLkr'] as num?)?.round() ?? 0,
      cashCoveredLkr: (data['cashCoveredLkr'] as num?)?.round() ?? 0,
      status: (data['status'] as String?)?.trim() ?? '',
      method: (data['method'] as String?)?.trim() ?? 'bank',
      reference: (ref == null || ref.isEmpty) ? null : ref,
      requestedAt: requested is Timestamp ? requested.toDate() : null,
    );
  }
}

class RiderCashRepository {
  RiderCashRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _auth = auth,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>>? _ledger() {
    final User? u = _auth.currentUser;
    if (u == null) {
      return null;
    }
    return _firestore
        .collection(FirebaseCollections.riders)
        .doc(u.uid)
        .collection(FirebaseCollections.riderCashLedger);
  }

  CollectionReference<Map<String, dynamic>>? _settlements() {
    final User? u = _auth.currentUser;
    if (u == null) {
      return null;
    }
    return _firestore
        .collection(FirebaseCollections.riders)
        .doc(u.uid)
        .collection(FirebaseCollections.riderCashSettlements);
  }

  /// Everything not yet settled — open entries plus the ones locked into a
  /// handover admin has still to confirm.
  Stream<List<RiderCashEntry>> watchOutstandingEntries({int limit = 60}) {
    final CollectionReference<Map<String, dynamic>>? col = _ledger();
    if (col == null) {
      return Stream<List<RiderCashEntry>>.value(const <RiderCashEntry>[]);
    }
    return col
        .where('status', whereIn: <String>['open', 'pending_settlement'])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      return snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              RiderCashEntry.fromDoc(d.id, d.data()))
          .toList(growable: false);
    });
  }

  /// The handover waiting on admin, if there is one.
  Stream<RiderCashSettlement?> watchPendingSettlement() {
    final CollectionReference<Map<String, dynamic>>? col = _settlements();
    if (col == null) {
      return Stream<RiderCashSettlement?>.value(null);
    }
    return col
        .where('status', isEqualTo: 'requested')
        .limit(1)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      if (snap.docs.isEmpty) {
        return null;
      }
      final QueryDocumentSnapshot<Map<String, dynamic>> d = snap.docs.first;
      return RiderCashSettlement.fromDoc(d.id, d.data());
    });
  }

  /// Cash ceiling from `platform_config/fees`, admin-editable.
  Stream<int> watchMaxCashInHandLkr() {
    return _firestore
        .collection(FirebaseCollections.platformConfig)
        .doc(FirebaseCollections.platformFeesDocId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snap) {
      final num? raw = snap.data()?['maxRiderCashInHandLkr'] as num?;
      if (raw == null || raw <= 0) {
        return kDefaultMaxCashInHandLkr;
      }
      return raw.round();
    });
  }

  /// Tells admin the rider is handing the cash over. Returns an error message,
  /// or null on success. The hold only lifts once admin confirms receipt.
  Future<String?> requestSettlement({
    required String method,
    String reference = '',
  }) async {
    if (_auth.currentUser == null) {
      return 'Not signed in.';
    }
    try {
      await _functions
          .httpsCallable('riderRequestCashSettlement')
          .call<dynamic>(<String, dynamic>{
        'method': method,
        'reference': reference.trim(),
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Could not request the handover.';
    } catch (e) {
      return userFacingError(e, fallback: 'Could not request the handover.');
    }
  }
}

final StreamProvider<List<RiderCashEntry>> riderOutstandingCashProvider =
    StreamProvider<List<RiderCashEntry>>((Ref ref) {
  return ref.watch(riderCashRepositoryProvider).watchOutstandingEntries();
});

final StreamProvider<RiderCashSettlement?> riderPendingCashSettlementProvider =
    StreamProvider<RiderCashSettlement?>((Ref ref) {
  return ref.watch(riderCashRepositoryProvider).watchPendingSettlement();
});

final StreamProvider<int> riderMaxCashInHandProvider = StreamProvider<int>((
  Ref ref,
) {
  return ref.watch(riderCashRepositoryProvider).watchMaxCashInHandLkr();
});
