import 'package:cloud_firestore/cloud_firestore.dart';

/// `riders/{riderId}/withdrawals/{id}`
enum RiderWithdrawalStatus {
  pending,
  approved,
  rejected,
  paid,
}

class RiderWithdrawal {
  const RiderWithdrawal({
    required this.id,
    required this.amountLkr,
    required this.status,
    required this.payoutMethod,
    required this.payoutAccount,
    this.note,
    this.createdAt,
    this.processedAt,
  });

  final String id;
  final double amountLkr;
  final RiderWithdrawalStatus status;
  final String payoutMethod;
  final String payoutAccount;
  final String? note;
  final DateTime? createdAt;
  final DateTime? processedAt;

  factory RiderWithdrawal.fromDoc(String id, Map<String, dynamic> data) {
    return RiderWithdrawal(
      id: id,
      amountLkr: _readDouble(data['amountLkr']),
      status: _parseStatus(data['status'] as String?),
      payoutMethod: (data['payoutMethod'] as String?)?.trim() ?? 'bank',
      payoutAccount: (data['payoutAccount'] as String?)?.trim() ?? '',
      note: (data['note'] as String?)?.trim(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      processedAt: data['processedAt'] is Timestamp
          ? (data['processedAt'] as Timestamp).toDate()
          : null,
    );
  }

  static RiderWithdrawalStatus _parseStatus(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'approved':
        return RiderWithdrawalStatus.approved;
      case 'rejected':
        return RiderWithdrawalStatus.rejected;
      case 'paid':
        return RiderWithdrawalStatus.paid;
      default:
        return RiderWithdrawalStatus.pending;
    }
  }

  static double _readDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
