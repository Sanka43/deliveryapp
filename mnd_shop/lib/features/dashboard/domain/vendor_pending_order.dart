import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mnd_shop/features/products/domain/product_option_labels.dart';

class VendorPendingOrder {
  const VendorPendingOrder({
    required this.id,
    required this.customerPhone,
    this.customerName = '',
    this.orderSource = '',
    this.isGuestCustomer = false,
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
    this.hasAssignedRider = false,
    this.assignedRiderId = '',
    this.deliveryAddressLabel = '',
    this.productCashStatus = '',
    this.productCashLkr = 0,
  });

  final String id;

  /// Customer phone from delivery address (empty when unknown).
  final String customerPhone;

  /// Display name when present (vendor-manual / guest orders).
  final String customerName;

  /// e.g. `vendor_manual` or empty for customer-app orders.
  final String orderSource;

  final bool isGuestCustomer;

  bool get isVendorManual => orderSource == 'vendor_manual';
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

  /// True when a rider has been assigned (`assignedRiderId` / `riderId`).
  final bool hasAssignedRider;

  /// Raw rider uid when assigned (empty otherwise) — used to fetch contact info.
  final String assignedRiderId;

  /// Single-line delivery / pickup address for kitchen UI.
  final String deliveryAddressLabel;

  /// Admin product-cash ledger: none | owed | remitted_to_admin | settled_to_shop.
  final String productCashStatus;
  final double productCashLkr;

  bool get isSelfPickup => fulfillmentMode == 'selfPickup';

  bool get hasProductCashLedger =>
      productCashStatus == 'owed' ||
      productCashStatus == 'remitted_to_admin' ||
      productCashStatus == 'settled_to_shop';

  String get productCashBadgeLabel {
    switch (productCashStatus) {
      case 'owed':
        return 'CASH OWED';
      case 'remitted_to_admin':
        return 'CASH WITH ADMIN';
      case 'settled_to_shop':
        return 'CASH SETTLED';
      default:
        return '';
    }
  }

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
    final String assigned =
        (data['assignedRiderId'] as String?)?.trim() ??
        (data['riderId'] as String?)?.trim() ??
        '';
    final String addressLabel = _addressLabel(addr);
    final String customerName =
        (data['customerName'] as String?)?.trim() ?? '';
    final String orderSource =
        (data['orderSource'] as String?)?.trim().toLowerCase() ?? '';
    return VendorPendingOrder(
      id: id,
      customerPhone: customerPhone,
      customerName: customerName,
      orderSource: orderSource,
      isGuestCustomer: data['isGuestCustomer'] == true,
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
      hasAssignedRider: assigned.isNotEmpty,
      assignedRiderId: assigned,
      deliveryAddressLabel: addressLabel,
      productCashStatus:
          (data['productCashStatus'] as String?)?.trim().toLowerCase() ?? '',
      productCashLkr: _readDouble(data['productCashLkr']),
    );
  }

  static String _addressLabel(Map<String, dynamic>? addr) {
    if (addr == null) {
      return '';
    }
    final List<String> parts = <String>[
      (addr['line1'] as String?)?.trim() ??
          (addr['addressLine1'] as String?)?.trim() ??
          '',
      (addr['line2'] as String?)?.trim() ??
          (addr['addressLine2'] as String?)?.trim() ??
          '',
      (addr['city'] as String?)?.trim() ?? '',
    ].where((String p) => p.isNotEmpty).toList();
    return parts.join(', ');
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
        final String selectedSize =
            (value['selectedSize'] as String?)?.trim() ?? '';
        final List<dynamic> extrasRaw =
            value['extras'] as List<dynamic>? ?? const <dynamic>[];
        final List<String> extras = extrasRaw
            .whereType<Map<String, dynamic>>()
            .map((Map<String, dynamic> e) => (e['name'] as String?)?.trim() ?? '')
            .where((String name) => name.isNotEmpty)
            .toList(growable: false);
        items.add(
          VendorOrderLineItem(
            productKey: productKey,
            productName: productName,
            quantity: quantity,
            lineTotal: lineTotal,
            selectedSize: selectedSize,
            extras: extras,
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
    this.selectedSize = '',
    this.extras = const <String>[],
  });

  final String productKey;
  final String productName;
  final int quantity;
  final double lineTotal;

  /// Size / variant chosen at checkout (e.g. `Large`), empty when not applicable.
  final String selectedSize;

  /// Add-on names chosen for this line (e.g. `Extra cheese`).
  final List<String> extras;

  /// Splits `selectedSize` into type + size using the product form's
  /// `{Type} · {Size}` combo convention (e.g. `Chicken · Full`). Falls back
  /// to a plain size with no type when it doesn't match that shape.
  ({String? type, String size}) get typeAndSize {
    final ({String type, String size})? combo =
        parseTypeSizeComboLabel(selectedSize);
    if (combo != null) {
      return (type: combo.type, size: combo.size);
    }
    return (type: null, size: selectedSize);
  }
}
