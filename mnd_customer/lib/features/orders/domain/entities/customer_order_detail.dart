import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_cancellation.dart';

class OrderDeliveryAddress {
  const OrderDeliveryAddress({
    required this.line1,
    required this.line2,
    required this.city,
    required this.phone,
  });

  final String line1;
  final String line2;
  final String city;
  final String phone;

  String get formatted {
    final StringBuffer b = StringBuffer(line1);
    if (line2.isNotEmpty) {
      b.write(', ');
      b.write(line2);
    }
    b.write('\n');
    b.write(city);
    b.write(' · ');
    b.write(phone);
    return b.toString();
  }

  factory OrderDeliveryAddress.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const OrderDeliveryAddress(
        line1: '',
        line2: '',
        city: '',
        phone: '',
      );
    }
    return OrderDeliveryAddress(
      line1: (map['line1'] as String?)?.trim() ?? '',
      line2: (map['line2'] as String?)?.trim() ?? '',
      city: (map['city'] as String?)?.trim() ?? '',
      phone: (map['phone'] as String?)?.trim() ?? '',
    );
  }
}

class OrderLineExtra {
  const OrderLineExtra({required this.name, required this.priceDelta});

  final String name;
  final int priceDelta;

  factory OrderLineExtra.fromMap(Map<String, dynamic> map) {
    return OrderLineExtra(
      name: (map['name'] as String?)?.trim() ?? '',
      priceDelta: OrderLineItem.readInt(map['priceDelta']),
    );
  }
}

class OrderLineItem {
  const OrderLineItem({
    required this.productKey,
    required this.storeId,
    required this.storeName,
    required this.productName,
    required this.quantity,
    required this.lineTotal,
    required this.selectedSize,
    required this.imageUrl,
    required this.extras,
    required this.basePrice,
    required this.sizePriceDelta,
  });

  /// From Firestore; may be empty on very old documents.
  final String productKey;
  final String storeId;
  final String storeName;
  final String productName;
  final int quantity;
  final int lineTotal;
  final String selectedSize;
  final String imageUrl;
  final List<OrderLineExtra> extras;
  final int basePrice;
  final int sizePriceDelta;

  static int readInt(dynamic v) {
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return 0;
  }

  factory OrderLineItem.fromMap(Map<String, dynamic> map) {
    final List<dynamic>? rawExtras = map['extras'] as List<dynamic>?;
    final List<OrderLineExtra> extras = rawExtras == null
        ? const <OrderLineExtra>[]
        : rawExtras
            .whereType<Map<String, dynamic>>()
            .map(OrderLineExtra.fromMap)
            .toList(growable: false);
    final int extrasSum = extras.fold<int>(0, (int s, OrderLineExtra e) => s + e.priceDelta);
    final int lineTotalVal = readInt(map['lineTotal']);
    final int qty = readInt(map['quantity']).clamp(1, 999);
    int base = readInt(map['basePrice']);
    int sizeDelta = readInt(map['sizePriceDelta']);
    final int unitFromDoc = readInt(map['unitPrice']);
    if (base == 0 && sizeDelta == 0) {
      final int unit = unitFromDoc > 0
          ? unitFromDoc
          : (qty > 0 ? lineTotalVal ~/ qty : 0);
      int remainder = unit - extrasSum;
      if (remainder < 0) {
        remainder = 0;
      }
      base = remainder;
    }

    return OrderLineItem(
      productKey: (map['productKey'] as String?)?.trim() ?? '',
      storeId: (map['storeId'] as String?)?.trim() ?? '',
      storeName: (map['storeName'] as String?)?.trim() ?? '',
      productName: (map['productName'] as String?)?.trim() ?? 'Item',
      quantity: qty,
      lineTotal: lineTotalVal,
      selectedSize: (map['selectedSize'] as String?)?.trim() ?? '',
      imageUrl: (map['imageUrl'] as String?)?.trim() ?? '',
      extras: extras,
      basePrice: base,
      sizePriceDelta: sizeDelta,
    );
  }
}

/// Full order document for the customer order details screen.
class CustomerOrderDetail {
  const CustomerOrderDetail({
    required this.id,
    required this.storeName,
    required this.vendorId,
    required this.statusRaw,
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    this.serviceCharge = 0,
    required this.total,
    required this.paymentMethod,
    this.paymentStatus = '',
    this.paidAt,
    required this.deliveryAddress,
    required this.deliveryNote,
    required this.specialInstructions,
    required this.items,
    required this.createdAt,
    this.couponCode,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.cancellationReasonId,
    this.cancellationReasonDetail,
    this.cancelledAt,
    this.cancelledBy,
    this.riderId,
    this.trackingNumber,
    this.storeRated = false,
    this.storeRatingStars,
    this.riderRated = false,
    this.riderRatingStars,
    this.fulfillmentMode = 'delivery',
  });

  final String id;
  final String storeName;
  final String vendorId;
  final String statusRaw;
  final int subtotal;
  final int discount;
  final int deliveryFee;
  final int serviceCharge;
  final int total;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime? paidAt;
  final OrderDeliveryAddress deliveryAddress;
  final String deliveryNote;
  final String specialInstructions;
  final List<OrderLineItem> items;
  final DateTime? createdAt;
  final String? couponCode;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final String? cancellationReasonId;
  final String? cancellationReasonDetail;
  final DateTime? cancelledAt;
  final String? cancelledBy;

  /// Assigned delivery rider (Auth UID; profile may live under `customers/{uid}`), when set.
  final String? riderId;

  /// Public tracking code (e.g. `MND2600012`); absent on legacy orders.
  final String? trackingNumber;

  /// True after the customer submitted a shop rating for this order.
  final bool storeRated;

  /// Stars the customer gave (1–5), when [storeRated] is true.
  final int? storeRatingStars;

  /// True after the customer submitted a rider rating for this order.
  final bool riderRated;

  /// Stars the customer gave the rider (1–5), when [riderRated] is true.
  final int? riderRatingStars;

  /// `delivery` or `selfPickup` from Firestore.
  final String fulfillmentMode;

  bool get isSelfPickup => fulfillmentMode.trim() == 'selfPickup';

  bool get isOnlinePayment => paymentMethod.toLowerCase().trim() == 'payhere';

  bool get isPaid => paymentStatus.toLowerCase().trim() == 'paid';

  /// User-visible order reference (never the Firestore document id).
  String get referenceForDisplay {
    final String? t = trackingNumber?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return '—';
  }

  /// User-facing line for a customer-cancelled order, or the raw id if unknown.
  String? get resolvedCancellationLabel {
    final String? id = cancellationReasonId;
    if (id == null || id.isEmpty) {
      return null;
    }
    return OrderCancellationReason.byId(id)?.label ?? id;
  }

  static int _readIntField(dynamic v) {
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return 0;
  }

  factory CustomerOrderDetail.fromDoc(String id, Map<String, dynamic> data) {
    final List<dynamic>? rawItems = data['items'] as List<dynamic>?;
    final List<OrderLineItem> items = rawItems == null
        ? const <OrderLineItem>[]
        : rawItems
            .whereType<Map<String, dynamic>>()
            .map(OrderLineItem.fromMap)
            .toList(growable: false);

    final Map<String, dynamic>? addrMap = data['deliveryAddress'] as Map<String, dynamic>?;
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final Timestamp? cancelledTs = data['cancelledAt'] as Timestamp?;
    final Timestamp? paidTs = data['paidAt'] as Timestamp?;

    final dynamic lat = data['dropoffLatitude'];
    final dynamic lng = data['dropoffLongitude'];

    return CustomerOrderDetail(
      id: id,
      storeName: (data['storeName'] as String?)?.trim() ?? 'Order',
      vendorId: (data['vendorId'] as String?)?.trim() ?? '',
      statusRaw: (data['status'] as String?)?.trim() ?? 'placed',
      subtotal: _readIntField(data['subtotal']),
      discount: _readIntField(data['discount']),
      deliveryFee: _readIntField(data['deliveryFee']),
      serviceCharge: _readIntField(data['serviceCharge']),
      total: _readIntField(data['total']),
      paymentMethod: (data['paymentMethod'] as String?)?.trim() ?? '',
      paymentStatus: (data['paymentStatus'] as String?)?.trim() ?? '',
      paidAt: paidTs?.toDate(),
      deliveryAddress: OrderDeliveryAddress.fromMap(addrMap),
      deliveryNote: (data['deliveryNote'] as String?)?.trim() ?? '',
      specialInstructions: (data['specialInstructions'] as String?)?.trim() ?? '',
      items: items,
      createdAt: ts?.toDate(),
      couponCode: (data['couponCode'] as String?)?.trim(),
      dropoffLatitude: lat is num ? lat.toDouble() : null,
      dropoffLongitude: lng is num ? lng.toDouble() : null,
      cancellationReasonId: (data['cancellationReason'] as String?)?.trim(),
      cancellationReasonDetail: (data['cancellationReasonDetail'] as String?)?.trim(),
      cancelledAt: cancelledTs?.toDate(),
      cancelledBy: (data['cancelledBy'] as String?)?.trim(),
      riderId: _readOptionalId(data['riderId'] ?? data['assignedRiderId']),
      trackingNumber: _readOptionalId(data['trackingNumber']),
      storeRated: data['storeRated'] == true,
      storeRatingStars: _readOptionalStars(data['storeRatingStars']),
      riderRated: data['riderRated'] == true,
      riderRatingStars: _readOptionalStars(data['riderRatingStars']),
      fulfillmentMode:
          (data['fulfillmentMode'] as String?)?.trim().isNotEmpty == true
              ? (data['fulfillmentMode'] as String).trim()
              : 'delivery',
    );
  }

  static int? _readOptionalStars(dynamic v) {
    if (v is int && v >= 1 && v <= 5) {
      return v;
    }
    if (v is num) {
      final int n = v.toInt();
      if (n >= 1 && n <= 5) {
        return n;
      }
    }
    return null;
  }

  static String? _readOptionalId(dynamic v) {
    if (v is String) {
      final String t = v.trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }
}
