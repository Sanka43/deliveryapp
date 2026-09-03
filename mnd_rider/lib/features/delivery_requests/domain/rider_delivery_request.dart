import 'package:mnd_rider/core/utils/geo_distance.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

/// Delivery type labels shown on the offer card.
enum RiderDeliveryType {
  standard('Standard delivery'),
  cashOnDelivery('Cash on delivery'),
  express('Express delivery');

  const RiderDeliveryType(this.label);

  final String label;

  static RiderDeliveryType fromOrderMap(Map<String, dynamic> data) {
    final String payment =
        (data['paymentMethod'] as String?)?.trim().toLowerCase() ?? '';
    if (payment == 'cashondelivery' || payment == 'cash_on_delivery') {
      return RiderDeliveryType.cashOnDelivery;
    }
    final String priority =
        (data['deliveryPriority'] as String?)?.trim().toLowerCase() ?? '';
    if (priority == 'express') {
      return RiderDeliveryType.express;
    }
    return RiderDeliveryType.standard;
  }
}

/// Enriched open job shown in the realtime offer popup.
class RiderDeliveryRequest {
  const RiderDeliveryRequest({
    required this.orderId,
    required this.vendorName,
    required this.deliveryType,
    required this.pickupAddress,
    required this.customerAddress,
    required this.estimatedEarningsLkr,
    required this.distanceToPickupKm,
    required this.routeKm,
    required this.itemsSummary,
    this.feeAfterTrip = false,
    this.productsPaid = false,
    this.trackingNumber,
    this.customerId,
    this.vendorId,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.offeredAt,
  });

  final String orderId;
  final String vendorName;
  final RiderDeliveryType deliveryType;
  final String pickupAddress;
  final String customerAddress;
  final int estimatedEarningsLkr;
  final double distanceToPickupKm;
  final double routeKm;
  final String itemsSummary;
  /// Vendor-manual actual-trip fee; earnings unknown until deliver.
  final bool feeAfterTrip;
  final bool productsPaid;
  final String? trackingNumber;
  final String? customerId;
  final String? vendorId;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final DateTime? offeredAt;

  double get estimatedPayout => estimatedEarningsLkr.toDouble();

  String get earningsLabel {
    if (feeAfterTrip) {
      return 'Fee after trip';
    }
    return 'Estimated earnings';
  }

  String get referenceForDisplay {
    final String? t = trackingNumber?.trim();
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return '—';
  }

  String get distanceToPickupLabel => GeoDistance.kmLabel(distanceToPickupKm);

  String get routeKmLabel => GeoDistance.kmLabel(routeKm);

  /// Back-compat alias for older UI code.
  String get storeName => vendorName;

  String get pickupAddressLine => pickupAddress;

  String get dropoffAddress => customerAddress;

  RiderOrderDetail toOrderDetail() {
    return RiderOrderDetail(
      id: orderId,
      status: 'ready',
      storeName: vendorName,
      vendorId: vendorId ?? '',
      customerId: customerId,
      totalLkr: 0,
      deliveryFeeLkr: estimatedEarningsLkr,
      productsPaid: productsPaid,
      deliveryFeeMode: feeAfterTrip ? 'actual_trip' : null,
      items: const <RiderOrderLineItem>[],
      deliveryAddress: RiderDeliveryAddress(
        line1: customerAddress,
        line2: '',
        city: '',
        phone: '',
      ),
      trackingNumber: trackingNumber,
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      pickupAddress: pickupAddress,
    );
  }

  RiderDeliveryRequest withDeliveryType(RiderDeliveryType type) {
    return RiderDeliveryRequest(
      orderId: orderId,
      vendorName: vendorName,
      deliveryType: type,
      pickupAddress: pickupAddress,
      customerAddress: customerAddress,
      estimatedEarningsLkr: estimatedEarningsLkr,
      distanceToPickupKm: distanceToPickupKm,
      routeKm: routeKm,
      itemsSummary: itemsSummary,
      feeAfterTrip: feeAfterTrip,
      productsPaid: productsPaid,
      trackingNumber: trackingNumber,
      customerId: customerId,
      vendorId: vendorId,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
      offeredAt: offeredAt,
    );
  }

  /// Recomputes [distanceToPickupKm] from a live rider position. Pure/local
  /// (uses the pickup coordinates already on this object) — does not touch
  /// Firestore, so callers can refresh distance on every GPS tick without
  /// re-querying open jobs.
  RiderDeliveryRequest withRiderPosition({
    required double? riderLat,
    required double? riderLng,
  }) {
    final double distance = GeoDistance.formatKm(
      GeoDistance.kmBetween(
        fromLat: riderLat,
        fromLng: riderLng,
        toLat: pickupLatitude,
        toLng: pickupLongitude,
      ),
    );
    return RiderDeliveryRequest(
      orderId: orderId,
      vendorName: vendorName,
      deliveryType: deliveryType,
      pickupAddress: pickupAddress,
      customerAddress: customerAddress,
      estimatedEarningsLkr: estimatedEarningsLkr,
      distanceToPickupKm: distance,
      routeKm: routeKm,
      itemsSummary: itemsSummary,
      feeAfterTrip: feeAfterTrip,
      productsPaid: productsPaid,
      trackingNumber: trackingNumber,
      customerId: customerId,
      vendorId: vendorId,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
      offeredAt: offeredAt,
    );
  }

  factory RiderDeliveryRequest.fromEnriched({
    required RiderOrderDetail order,
    required double? riderLat,
    required double? riderLng,
    String? vendorPickupAddress,
    double? vendorPickupLat,
    double? vendorPickupLng,
  }) {
    final double? pickupLat = order.pickupLatitude ?? vendorPickupLat;
    final double? pickupLng = order.pickupLongitude ?? vendorPickupLng;
    final double? dropLat = order.dropoffLatitude;
    final double? dropLng = order.dropoffLongitude;

    final double distanceToPickup = GeoDistance.formatKm(
      GeoDistance.kmBetween(
        fromLat: riderLat,
        fromLng: riderLng,
        toLat: pickupLat,
        toLng: pickupLng,
      ),
    );

    final double route = GeoDistance.formatKm(
      GeoDistance.kmBetween(
        fromLat: pickupLat,
        fromLng: pickupLng,
        toLat: dropLat,
        toLng: dropLng,
      ),
    );

    final String pickup = (order.pickupAddress?.trim().isNotEmpty ?? false)
        ? order.pickupAddress!.trim()
        : (vendorPickupAddress?.trim().isNotEmpty ?? false)
            ? vendorPickupAddress!.trim()
            : order.storeName;

    final bool feeAfterTrip = order.deliveryFeePending;

    return RiderDeliveryRequest(
      orderId: order.id,
      vendorName: order.storeName,
      deliveryType: RiderDeliveryType.standard,
      pickupAddress: pickup,
      customerAddress: order.dropoffAddressSingleLine,
      estimatedEarningsLkr:
          feeAfterTrip ? 0 : (order.deliveryFeeLkr > 0 ? order.deliveryFeeLkr : 0),
      distanceToPickupKm: distanceToPickup,
      routeKm: route,
      itemsSummary: order.itemsSummary,
      feeAfterTrip: feeAfterTrip,
      productsPaid: order.productsPaid,
      trackingNumber: order.trackingNumber,
      customerId: order.customerId,
      vendorId: order.vendorId,
      pickupLatitude: pickupLat,
      pickupLongitude: pickupLng,
      dropoffLatitude: dropLat,
      dropoffLongitude: dropLng,
      offeredAt: DateTime.now(),
    );
  }
}
