import 'package:cloud_firestore/cloud_firestore.dart';

/// A payout request under `vendors/{vendorId}/payouts/{payoutId}`.
class VendorPayout {
  const VendorPayout({
    required this.id,
    required this.amountLkr,
    required this.status,
    required this.payoutMethod,
    required this.payoutAccount,
    this.note = '',
    this.createdAt,
    this.processedAt,
  });

  final String id;
  final double amountLkr;

  /// `pending` | `paid` | `rejected`
  final String status;

  /// `bank` | `mobile`
  final String payoutMethod;
  final String payoutAccount;
  final String note;
  final DateTime? createdAt;
  final DateTime? processedAt;

  bool get isPending => status == 'pending';
  bool get isPaid => status == 'paid';
  bool get isRejected => status == 'rejected';

  factory VendorPayout.fromFirestore(String id, Map<String, dynamic> data) {
    return VendorPayout(
      id: id,
      amountLkr: _readDouble(data['amountLkr']),
      status: (data['status'] as String?)?.trim().toLowerCase().isNotEmpty == true
          ? (data['status'] as String).trim().toLowerCase()
          : 'pending',
      payoutMethod: (data['payoutMethod'] as String?)?.trim().toLowerCase() ?? '',
      payoutAccount: (data['payoutAccount'] as String?)?.trim() ?? '',
      note: (data['note'] as String?)?.trim() ?? '',
      createdAt: _readDate(data['createdAt']),
      processedAt: _readDate(data['processedAt']),
    );
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
