import 'package:cloud_firestore/cloud_firestore.dart';

/// Ledger row: `riders/{riderId}/transactions/{id}`
enum RiderTransactionType {
  deliveryEarning,
  withdrawal,
  adjustment,
}

enum RiderTransactionStatus {
  completed,
  pending,
  failed,
  cancelled,
}

class RiderTransaction {
  const RiderTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.amountLkr,
    required this.title,
    required this.subtitle,
    this.orderId,
    this.withdrawalId,
    this.createdAt,
  });

  final String id;
  final RiderTransactionType type;
  final RiderTransactionStatus status;
  final double amountLkr;
  final String title;
  final String subtitle;
  final String? orderId;
  final String? withdrawalId;
  final DateTime? createdAt;

  bool get isCredit => amountLkr >= 0;

  factory RiderTransaction.fromDoc(String id, Map<String, dynamic> data) {
    return RiderTransaction(
      id: id,
      type: _parseType(data['type'] as String?),
      status: _parseStatus(data['status'] as String?),
      amountLkr: _readDouble(data['amountLkr']),
      title: (data['title'] as String?)?.trim() ?? 'Transaction',
      subtitle: (data['subtitle'] as String?)?.trim() ?? '',
      orderId: (data['orderId'] as String?)?.trim(),
      withdrawalId: (data['withdrawalId'] as String?)?.trim(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  static RiderTransactionType _parseType(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'delivery_earning':
        return RiderTransactionType.deliveryEarning;
      case 'withdrawal':
        return RiderTransactionType.withdrawal;
      case 'adjustment':
        return RiderTransactionType.adjustment;
      default:
        return RiderTransactionType.adjustment;
    }
  }

  static RiderTransactionStatus _parseStatus(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'pending':
        return RiderTransactionStatus.pending;
      case 'failed':
        return RiderTransactionStatus.failed;
      case 'cancelled':
        return RiderTransactionStatus.cancelled;
      default:
        return RiderTransactionStatus.completed;
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
