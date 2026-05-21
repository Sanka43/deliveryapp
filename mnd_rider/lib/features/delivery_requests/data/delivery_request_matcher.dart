import 'package:mnd_rider/features/delivery_requests/domain/delivery_request_config.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';

/// Filters and ranks open jobs for the signed-in rider.
class DeliveryRequestMatcher {
  const DeliveryRequestMatcher({this.config = DeliveryRequestConfig.defaults});

  final DeliveryRequestConfig config;

  List<RiderDeliveryRequest> matchNearby({
    required List<RiderDeliveryRequest> candidates,
    required Set<String> dismissedOrderIds,
    double? riderLat,
    double? riderLng,
  }) {
    final List<RiderDeliveryRequest> filtered = <RiderDeliveryRequest>[];

    for (final RiderDeliveryRequest r in candidates) {
      if (dismissedOrderIds.contains(r.orderId)) {
        continue;
      }
      if (riderLat != null &&
          riderLng != null &&
          r.pickupLatitude != null &&
          r.pickupLongitude != null &&
          r.distanceToPickupKm > config.maxPickupRadiusKm) {
        continue;
      }
      filtered.add(r);
    }

    filtered.sort((RiderDeliveryRequest a, RiderDeliveryRequest b) {
      final int dist = a.distanceToPickupKm.compareTo(b.distanceToPickupKm);
      if (dist != 0) {
        return dist;
      }
      final DateTime aTime = a.offeredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bTime = b.offeredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    if (filtered.length > config.maxConcurrentOffers) {
      return filtered.sublist(0, config.maxConcurrentOffers);
    }
    return filtered;
  }

  RiderDeliveryRequest? pickNextOffer({
    required List<RiderDeliveryRequest> matched,
    String? currentlyShowingOrderId,
  }) {
    if (matched.isEmpty) {
      return null;
    }
    if (currentlyShowingOrderId != null) {
      for (final RiderDeliveryRequest r in matched) {
        if (r.orderId == currentlyShowingOrderId) {
          return r;
        }
      }
    }
    return matched.first;
  }
}
