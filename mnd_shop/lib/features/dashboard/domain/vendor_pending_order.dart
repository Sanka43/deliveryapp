import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class VendorPendingOrder {
  const VendorPendingOrder({
    required this.id,
    required this.customerPhone,
    required this.itemsSummary,
    required this.itemLines,
    this.items = const <VendorOrderLineItem>[],
    required this.total,
    this.deliveryFee = 0,
    this.orderCommission = 0,
    this.subtotal = 0,
    this.discount = 0,
    required this.placedAtLabel,
    this.createdAt,
    this.itemCount = 0,
    this.statusKey = '',
    this.trackingNumber,
    this.fulfillmentMode = 'delivery',
  });

  final String id;

  /// Customer phone from delivery address (empty when unknown).
  final String customerPhone;
  final String itemsSummary;

  /// One line per order item (e.g. `2× Faluda`) for bulleted UI lists.
  final List<String> itemLines;
  final List<VendorOrderLineItem> items;

  final double total;
  final double deliveryFee;
  final double orderCommission;
  final double subtotal;
  final double discount;
  final String placedAtLabel;

  /// Order placement time from Firestore `createdAt` (for sales aggregates).
  final DateTime? createdAt;

  /// Number of line items (from Firestore `items` array length).
  final int itemCount;

  /// Firestore [status] lowercased (e.g. placed, confirmed, preparing, ready).
  final String statusKey;

  /// Public tracking code when present on the order document.
  final String? trackingNumber;

  /// `delivery` or `selfPickup` from Firestore.
  final String fulfillmentMode;

  bool get isSelfPickup => fulfillmentMode == 'selfPickup';

  /// Shop keeps product sales only (excludes delivery + platform order commission).
  double get shopTotal {
    if (subtotal > 0 || discount > 0) {
      return math.max(0, subtotal - discount);
    }
    return math.max(0, total - deliveryFee - orderCommission);
  }

  String get referenceForDisplay {
    final String? t = trackingNumber?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return '-';
  }

  factory VendorPendingOrder.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final Map<String, dynamic>? addr =
        data['deliveryAddress'] as Map<String, dynamic>?;
    final String phone = (addr?['phone'] as String?)?.trim() ?? '';
    final String customerPhone = phone;
    final List<dynamic> raw =
        data['items'] as List<dynamic>? ?? const <dynamic>[];
    final List<VendorOrderLineItem> items = _items(raw);
    final int itemCount = items.fold<int>(
      0,
      (int total, VendorOrderLineItem item) => total + item.quantity,
    );
    final List<String> itemLines = _itemLines(items);
    final String itemsSummary = _itemsSummary(itemLines);
    final double total = _readDouble(
      data['total'] ?? data['grandTotal'] ?? data['orderTotal'],
    );
    final double deliveryFee = _readDouble(
      data['deliveryFee'] ?? data['deliveryCharge'] ?? data['shippingFee'],
    );
    final double orderCommission = _readDouble(data['orderCommissionLkr']);
    final double subtotal = _readDouble(data['subtotal']);
    final double discount = _readDouble(data['discount']);
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final DateTime? createdAt = ts?.toDate();
    final String placedAt = _formatTs(ts);
    final String status =
        (data['status'] as String?)?.trim().toLowerCase() ?? '';
    final String? tn = (data['trackingNumber'] as String?)?.trim();
    return VendorPendingOrder(
      id: id,
      customerPhone: customerPhone,
      itemsSummary: itemsSummary,
      itemLines: itemLines,
      items: items,
      total: total,
      deliveryFee: deliveryFee,
      orderCommission: orderCommission,
      subtotal: subtotal,
      discount: discount,
      placedAtLabel: placedAt,
      createdAt: createdAt,
      itemCount: itemCount,
      statusKey: status,
      trackingNumber: (tn == null || tn.isEmpty) ? null : tn,
      fulfillmentMode:
          (data['fulfillmentMode'] as String?)?.trim().isNotEmpty == true
          ? (data['fulfillmentMode'] as String).trim()
          : 'delivery',
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

  static double _readDouble(Object? v) {
    if (v is num) {
      return v.toDouble();
    }
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static List<VendorOrderLineItem> _items(List<dynamic> raw) {
    if (raw.isEmpty) {
      return const <VendorOrderLineItem>[];
    }
    final List<VendorOrderLineItem> items = <VendorOrderLineItem>[];
    for (final Object? value in raw) {
      if (value is Map<String, dynamic>) {
        final String productName =
            (value['productName'] as String?)?.trim().isNotEmpty == true
            ? (value['productName'] as String).trim()
            : 'Order item';
        final String productKey =
            (value['productKey'] as String?)?.trim().isNotEmpty == true
            ? (value['productKey'] as String).trim()
            : productName;
        final int quantity = math.max(1, _readInt(value['quantity']));
        final double lineTotal = _readDouble(value['lineTotal']);
        items.add(
          VendorOrderLineItem(
            productKey: productKey,
            productName: productName,
            quantity: quantity,
            lineTotal: lineTotal,
          ),
        );
      }
    }
    return items;
  }

  static List<String> _itemLines(List<VendorOrderLineItem> items) {
    if (items.isEmpty) {
      return const <String>[];
    }
    final List<String> lines = <String>[];
    for (final VendorOrderLineItem item in items) {
      lines.add('${item.quantity} x ${item.productName}');
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

class VendorOrderLineItem {
  const VendorOrderLineItem({
    required this.productKey,
    required this.productName,
    required this.quantity,
    required this.lineTotal,
  });

  final String productKey;
  final String productName;
  final int quantity;
  final double lineTotal;
}
