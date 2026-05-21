import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/delivery_requests/data/delivery_request_matcher.dart';
import 'package:mnd_rider/features/delivery_requests/data/rider_delivery_requests_repository.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/order_request_session_provider.dart';

final StreamProvider<RiderPosition?> riderPositionStreamProvider =
    StreamProvider<RiderPosition?>((Ref ref) {
  return ref.watch(riderDeliveryRequestsRepositoryProvider).watchRiderPosition();
});

/// Raw Firestore stream of open jobs enriched with pickup/distance.
final StreamProvider<List<RiderDeliveryRequest>> rawOpenDeliveryRequestsProvider =
    StreamProvider<List<RiderDeliveryRequest>>((Ref ref) {
  final bool online = ref.watch(riderDashboardProvider).isOnline;
  final bool approved = ref.watch(riderIsApprovedToDriveProvider);
  if (!online || !approved) {
    return Stream<List<RiderDeliveryRequest>>.value(const <RiderDeliveryRequest>[]);
  }
  final RiderPosition? pos = ref.watch(riderPositionStreamProvider).valueOrNull;
  return ref.watch(riderDeliveryRequestsRepositoryProvider).watchOpenDeliveryRequests(
        riderLatitude: pos?.latitude,
        riderLongitude: pos?.longitude,
      );
});

/// Nearby + not dismissed, sorted by distance to pickup.
final Provider<AsyncValue<List<RiderDeliveryRequest>>> matchedNearbyDeliveryRequestsProvider =
    Provider<AsyncValue<List<RiderDeliveryRequest>>>((Ref ref) {
  final AsyncValue<List<RiderDeliveryRequest>> raw =
      ref.watch(rawOpenDeliveryRequestsProvider);
  final Set<String> dismissed =
      ref.watch(orderRequestSessionProvider).dismissedOrderIds;
  final RiderPosition? pos = ref.watch(riderPositionStreamProvider).valueOrNull;

  return raw.whenData((List<RiderDeliveryRequest> list) {
    return const DeliveryRequestMatcher().matchNearby(
      candidates: list,
      dismissedOrderIds: dismissed,
      riderLat: pos?.latitude,
      riderLng: pos?.longitude,
    );
  });
});
