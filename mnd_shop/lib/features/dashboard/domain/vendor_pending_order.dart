import 'package:cloud_firestore/cloud_firestore.dart';

class VendorPendingOrder {
  const VendorPendingOrder({
    required this.id,
    required this.customerPhone,
    required this.itemsSummary,
    required this.itemLines,
    required this.total,
    required this.placedAtLabel,
    this.createdAt,
    this.itemCount = 0,
    this.statusKey = '',
    this.trackingNumber,
  });

  final String id;

  /// Customer phone from delivery address (empty when unknown).
  final String customerPhone;
  final String itemsSummary;

  /// One line per order item (e.g. `2× Faluda`) for bulleted UI lists.
  final List<String> itemLines;

  final double total;
  final String placedAtLabel;

  /// Order placement time from Firestore `createdAt` (for sales aggregates).
  final DateTime? createdAt;

  /// Number of line items (from Firestore `items` array length).
  final int itemCount;

  /// Firestore [status] lowercased (e.g. placed, confirmed, preparing, ready).
  final String statusKey;

  /// Public tracking code when present on the order document.
  final String? trackingNumber;

  String get referenceForDisplay {
    final String? t = trackingNumber?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return '-';
  }

  factory VendorPendingOrder.fromFirestore(String id, Map<String, dynamic> data) {
    final Map<String, dynamic>? addr = data['deliveryAddress'] as Map<String, dynamic>?;
    final String phone = (addr?['phone'] as String?)?.trim() ?? '';
    final String customerPhone = phone;
    final List<dynamic> raw = data['items'] as List<dynamic>? ?? const <dynamic>[];
    final int itemCount = raw.length;
    final List<String> itemLines = _itemLines(raw);
    final String itemsSummary = _itemsSummary(itemLines);
    final int totalInt = _readInt(data['total']);
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final DateTime? createdAt = ts?.toDate();
    final String placedAt = _formatTs(ts);
    final String status = (data['status'] as String?)?.trim().toLowerCase() ?? '';
    final String? tn = (data['trackingNumber'] as String?)?.trim();
    return VendorPendingOrder(
      id: id,
      customerPhone: customerPhone,
      itemsSummary: itemsSummary,
      itemLines: itemLines,
      total: totalInt.toDouble(),
      placedAtLabel: placedAt,
      createdAt: createdAt,
      itemCount: itemCount,
      statusKey: status,
      trackingNumber: (tn == null || tn.isEmpty) ? null : tn,
    );
  }

  static int _readInt(Object? v) {
    if (v is int) {
      return v;
    }
    if (v is double) {
      return v.round();
    }
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static List<String> _itemLines(List<dynamic> raw) {
    if (raw.isEmpty) {
      return const <String>[];
    }
    final List<String> lines = <String>[];
    for (final Object? e in raw) {
      if (e is Map<String, dynamic>) {
        final String name = (e['productName'] as String?)?.trim() ?? 'Item';
        final int q = _readInt(e['quantity']);
        lines.add('$q× $name');
      }
    }
    return lines;
  }

  static String _itemsSummary(List<String> itemLines) {
    if (itemLines.isEmpty) {
      return 'No line items';
    }
    return itemLines.take(3).join(', ');
  }

  static String _formatTs(Timestamp? ts) {
    if (ts == null) {
      return '';
    }
    final DateTime d = ts.toDate();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
