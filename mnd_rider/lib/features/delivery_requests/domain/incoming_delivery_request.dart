import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

/// Legacy name for [RiderDeliveryRequest].
typedef IncomingDeliveryRequest = RiderDeliveryRequest;

/// Builds an offer model from a Firestore order snapshot.
RiderDeliveryRequest incomingDeliveryRequestFromOrder(RiderOrderDetail order) {
  return RiderDeliveryRequest.fromEnriched(
    order: order,
    riderLat: null,
    riderLng: null,
  );
}
