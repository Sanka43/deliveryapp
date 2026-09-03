import 'package:cloud_firestore/cloud_firestore.dart';

/// Full order payload for rider trip, incoming offer, and detail screens.
class RiderOrderDetail {
  const RiderOrderDetail({
    required this.id,
    required this.status,
    required this.storeName,
    required this.vendorId,
    this.customerId,
    this.isGuestCustomer = false,
    required this.totalLkr,
    required this.deliveryFeeLkr,
    this.subtotalLkr = 0,
    this.discountLkr = 0,
    this.serviceChargeLkr = 0,
    this.productsPaid = false,
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.deliveryFeeMode,
    this.amountDueFromCustomerLkr,
    this.traveledKm,
    required this.items,
    required this.deliveryAddress,
    this.trackingNumber,
    this.createdAt,
    this.deliveredAt,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.pickupLatitude,
    this.pickupLongitude,
    this.pickupAddress,
    this.deliveryNote,
  });

  final String id;
  final String status;
  final String storeName;
  final String vendorId;
  final String? customerId;
  /// Phone didn't match an MND account — delivery needs the SMS'd code.
  final bool isGuestCustomer;
  final int totalLkr;
  final int deliveryFeeLkr;
  final int subtotalLkr;
  final int discountLkr;
  final int serviceChargeLkr;
  /// Customer already paid shop for products; rider collects delivery only.
  final bool productsPaid;
  final String paymentMethod;
  final String paymentStatus;
  /// `actual_trip` → fee finalized from path KM on deliver.
  final String? deliveryFeeMode;
  final int? amountDueFromCustomerLkr;
  final double? traveledKm;
  final List<RiderOrderLineItem> items;
  final RiderDeliveryAddress deliveryAddress;
  final String? trackingNumber;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? pickupAddress;
  final String? deliveryNote;

  bool get usesActualTripFee =>
      (deliveryFeeMode ?? '').trim().toLowerCase() == 'actual_trip';

  /// This order was originally Cash on Delivery but the customer paid
  /// online afterwards — the rider must not collect cash for it.
  bool get isPrepaidOnline =>
      paymentMethod.trim().toLowerCase() == 'payhere' &&
      paymentStatus.trim().toLowerCase() == 'paid';

  bool get deliveryFeePending =>
      usesActualTripFee && deliveryFeeLkr <= 0 && status != 'delivered';

  /// Amount rider should collect after fee is known (or estimated).
  int collectAmountLkr({int? estimatedDeliveryFeeLkr}) {
    final int fee = estimatedDeliveryFeeLkr ?? deliveryFeeLkr;
    if (amountDueFromCustomerLkr != null && deliveryFeeLkr > 0) {
      return amountDueFromCustomerLkr!;
    }
    if (productsPaid) {
      return fee + serviceChargeLkr;
    }
    return (subtotalLkr - discountLkr + fee + serviceChargeLkr).clamp(
      0,
      1 << 30,
    );
  }

  bool get isActiveDelivery {
    const Set<String> active = <String>{
      'out_for_delivery',
      'picked_up',
      'on_the_way',
    };
    return active.contains(status);
  }

  String get referenceForDisplay {
    final String? t = trackingNumber?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return '—';
  }

  String get dropoffAddressSingleLine => deliveryAddress.singleLine;

  String get itemsSummary {
    if (items.isEmpty) {
      return 'Order';
    }
    final int qty = items.fold<int>(0, (int s, RiderOrderLineItem i) => s + i.quantity);
    return '$qty item${qty == 1 ? '' : 's'}';
  }

  static double? readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static int readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory RiderOrderDetail.fromDoc(String id, Map<String, dynamic> data) {
    final List<dynamic> rawItems = data['items'] as List<dynamic>? ?? <dynamic>[];
    final List<RiderOrderLineItem> items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(RiderOrderLineItem.fromMap)
        .toList(growable: false);

    final Map<String, dynamic>? addr =
        data['deliveryAddress'] as Map<String, dynamic>?;

    final dynamic createdAtRaw = data['createdAt'];
    final DateTime? createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : null;
    final dynamic deliveredAtRaw = data['deliveredAt'];
    final DateTime? deliveredAt = deliveredAtRaw is Timestamp
        ? deliveredAtRaw.toDate()
        : null;

    final String? tn = (data['trackingNumber'] as String?)?.trim();

    return RiderOrderDetail(
      id: id,
      status: (data['status'] as String?)?.trim().toLowerCase() ?? '',
      storeName: (data['storeName'] as String?)?.trim() ?? 'Store',
      vendorId: (data['vendorId'] as String?)?.trim() ?? '',
      customerId: (data['customerId'] as String?)?.trim(),
      isGuestCustomer: data['isGuestCustomer'] == true,
      totalLkr: readInt(data['total']),
      deliveryFeeLkr: readInt(data['deliveryFee']),
      subtotalLkr: readInt(data['subtotal']),
      discountLkr: readInt(data['discount']),
      serviceChargeLkr: readInt(data['serviceCharge']),
      productsPaid: data['productsPaid'] == true,
      paymentMethod: (data['paymentMethod'] as String?)?.trim() ?? '',
      paymentStatus: (data['paymentStatus'] as String?)?.trim() ?? '',
      deliveryFeeMode: (data['deliveryFeeMode'] as String?)?.trim(),
      amountDueFromCustomerLkr: data['amountDueFromCustomer'] == null
          ? null
          : readInt(data['amountDueFromCustomer']),
      traveledKm: readDouble(data['traveledKm']),
      items: items,
      deliveryAddress: RiderDeliveryAddress.fromMap(addr),
      trackingNumber: (tn == null || tn.isEmpty) ? null : tn,
      createdAt: createdAt,
      deliveredAt: deliveredAt,
      dropoffLatitude: readDouble(data['dropoffLatitude']),
      dropoffLongitude: readDouble(data['dropoffLongitude']),
      pickupLatitude: readDouble(data['pickupLatitude']),
      pickupLongitude: readDouble(data['pickupLongitude']),
      pickupAddress: (data['pickupAddress'] as String?)?.trim(),
      deliveryNote: (data['deliveryNote'] as String?)?.trim(),
    );
  }
}

class RiderOrderLineItem {
  const RiderOrderLineItem({
    required this.productName,
    required this.quantity,
  });

  final String productName;
  final int quantity;

  factory RiderOrderLineItem.fromMap(Map<String, dynamic> map) {
    return RiderOrderLineItem(
      productName: (map['productName'] as String?)?.trim() ?? 'Item',
      quantity: RiderOrderDetail.readInt(map['quantity']).clamp(1, 999),
    );
  }
}

class RiderDeliveryAddress {
  const RiderDeliveryAddress({
    required this.line1,
    required this.line2,
    required this.city,
    required this.phone,
  });

  final String line1;
  final String line2;
  final String city;
  final String phone;

  String get singleLine {
    final List<String> parts = <String>[
      line1,
      if (line2.isNotEmpty) line2,
      city,
    ].where((String s) => s.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  factory RiderDeliveryAddress.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const RiderDeliveryAddress(
        line1: '',
        line2: '',
        city: '',
        phone: '',
      );
    }
    return RiderDeliveryAddress(
      line1: (map['line1'] as String?)?.trim() ?? '',
      line2: (map['line2'] as String?)?.trim() ?? '',
      city: (map['city'] as String?)?.trim() ?? '',
      phone: (map['phone'] as String?)?.trim() ?? '',
    );
  }
}
