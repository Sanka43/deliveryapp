import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/admin/data/admin_product_cash_repository.dart';

final Provider<AdminWithdrawalsRepository> adminWithdrawalsRepositoryProvider =
    Provider<AdminWithdrawalsRepository>((Ref ref) {
  return AdminWithdrawalsRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

class AdminWithdrawalRow {
  const AdminWithdrawalRow({
    required this.id,
    required this.riderId,
    required this.amountLkr,
    required this.status,
    required this.payoutMethod,
    required this.payoutAccount,
    this.note,
    this.createdAt,
  });

  final String id;
  final String riderId;
  final int amountLkr;
  final String status;
  final String payoutMethod;
  final String payoutAccount;
  final String? note;
  final DateTime? createdAt;

  factory AdminWithdrawalRow.fromSnap(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final Map<String, dynamic> data = d.data();
    final String riderId = (data['riderId'] as String?)?.trim().isNotEmpty == true
        ? (data['riderId'] as String).trim()
        : (d.reference.parent.parent?.id ?? '');
    final dynamic createdRaw = data['createdAt'];
    final int amount = data['amountLkr'] is int
        ? data['amountLkr'] as int
        : (data['amountLkr'] is num ? (data['amountLkr'] as num).round() : 0);
    return AdminWithdrawalRow(
      id: d.id,
      riderId: riderId,
      amountLkr: amount,
      status: (data['status'] as String?)?.trim().toLowerCase() ?? 'pending',
      payoutMethod: (data['payoutMethod'] as String?)?.trim() ?? '',
      payoutAccount: (data['payoutAccount'] as String?)?.trim() ?? '',
      note: (data['note'] as String?)?.trim(),
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : null,
    );
  }
}

class AdminWithdrawalsRepository {
  AdminWithdrawalsRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _auth = auth,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Stream<List<AdminWithdrawalRow>> watchPending({int limit = 50}) {
    if (_auth.currentUser == null) {
      return Stream<List<AdminWithdrawalRow>>.value(
        const <AdminWithdrawalRow>[],
      );
    }
    return _firestore
        .collectionGroup(FirebaseCollections.riderWithdrawals)
        .where('status', whereIn: <String>['pending', 'approved'])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(AdminWithdrawalRow.fromSnap)
              .toList(growable: false),
        );
  }

  Future<String?> settle({
    required String riderId,
    required String withdrawalId,
    required String action,
  }) async {
    try {
      await _functions.httpsCallable('adminSettleRiderWithdrawal').call(
        <String, dynamic>{
          'riderId': riderId.trim(),
          'withdrawalId': withdrawalId.trim(),
          'action': action.trim(),
        },
      );
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : 'Could not settle withdrawal.';
    } catch (_) {
      return 'Could not settle withdrawal.';
    }
  }
}
