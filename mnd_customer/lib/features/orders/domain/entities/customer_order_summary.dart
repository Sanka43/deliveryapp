import 'package:cloud_firestore/cloud_firestore.dart';

/// Lightweight order row for customer order history.
class CustomerOrderSummary {
  const CustomerOrderSummary({
    required this.id,
    required this.storeName,
    required this.statusRaw,
    required this.totalLkr,
    required this.createdAt,
    this.trackingNumber,
  });

  final String id;
  final String storeName;
  final String statusRaw;
  final int totalLkr;
  final DateTime? createdAt;
  final String? trackingNumber;

  /// User-visible order reference (never the Firestore document id).
  String get referenceForDisplay {
    final String? t = trackingNumber?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return '—';
  }

  static const Set<String> _terminalStatuses = <String>{
    'delivered',
    'cancelled',
  };

  bool get isCompleted {
    return _terminalStatuses.contains(statusRaw.toLowerCase().trim());
  }

  String get displayStatus {
    final String key = statusRaw.toLowerCase().trim();
    switch (key) {
      case 'placed':
        return 'Placed';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'ready':
        return 'Ready for pickup';
      case 'out_for_delivery':
      case 'on_the_way':
        return 'On the way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        if (statusRaw.isEmpty) {
          return 'Placed';
        }
        return statusRaw[0].toUpperCase() + statusRaw.substring(1);
    }
  }

  factory CustomerOrderSummary.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final dynamic rawTotal = data['total'];
    int totalLkr = 0;
    if (rawTotal is int) {
      totalLkr = rawTotal;
    } else if (rawTotal is num) {
      totalLkr = rawTotal.toInt();
    }
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final String? tn = (data['trackingNumber'] as String?)?.trim();
    return CustomerOrderSummary(
      id: id,
      storeName: (data['storeName'] as String?)?.trim() ?? 'Order',
      statusRaw: (data['status'] as String?)?.trim() ?? 'placed',
      totalLkr: totalLkr,
      createdAt: ts?.toDate(),
      trackingNumber: (tn == null || tn.isEmpty) ? null : tn,
    );
  }
}
