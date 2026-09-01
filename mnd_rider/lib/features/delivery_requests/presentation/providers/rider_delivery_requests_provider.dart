import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/delivery_requests/data/delivery_request_matcher.dart';
import 'package:mnd_rider/features/delivery_requests/data/rider_delivery_requests_repository.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/order_request_session_provider.dart';
import 'package:mnd_rider/features/earnings/presentation/providers/rider_cash_hold_provider.dart';

final StreamProvider<RiderPosition?> riderPositionStreamProvider =
    StreamProvider<RiderPosition?>((Ref ref) {
  return ref.watch(riderDeliveryRequestsRepositoryProvider).watchRiderPosition();
});

/// Raw Firestore stream of open jobs (pickup/dropoff enriched, no distance
/// yet). Independent of rider position on purpose: the underlying query
/// never filtered by location, so recreating this listener on every GPS
/// update only churned Firestore reads for no benefit. Distance is attached
/// by [openDeliveryRequestsProvider] instead.
final StreamProvider<List<RiderDeliveryRequest>> rawOpenDeliveryRequestsProvider =
    StreamProvider<List<RiderDeliveryRequest>>((Ref ref) {
  final bool online = ref.watch(riderDashboardProvider).isOnline;
  final bool approved = ref.watch(riderIsApprovedToDriveProvider);
  // Cash hold blocks claiming a delivery just as it blocks a ride, so stop
  // offering them rather than failing at Accept.
  final bool cashHeld = ref.watch(riderCashHoldActiveProvider);
  if (!online || !approved || cashHeld) {
    return Stream<List<RiderDeliveryRequest>>.value(const <RiderDeliveryRequest>[]);
  }
  return ref.watch(riderDeliveryRequestsRepositoryProvider).watchOpenDeliveryRequests();
});

/// [rawOpenDeliveryRequestsProvider] with distance-to-pickup recomputed from
/// the latest rider position. Purely local recombination (no new Firestore
/// listener) — safe to recompute on every GPS tick.
final Provider<AsyncValue<List<RiderDeliveryRequest>>> openDeliveryRequestsProvider =
    Provider<AsyncValue<List<RiderDeliveryRequest>>>((Ref ref) {
  final AsyncValue<List<RiderDeliveryRequest>> raw =
      ref.watch(rawOpenDeliveryRequestsProvider);
  final RiderPosition? pos = ref.watch(riderPositionStreamProvider).valueOrNull;

  return raw.whenData((List<RiderDeliveryRequest> list) {
    return list
        .map((RiderDeliveryRequest r) => r.withRiderPosition(
              riderLat: pos?.latitude,
              riderLng: pos?.longitude,
            ))
        .toList(growable: false);
  });
});

/// Nearby + not dismissed, sorted by distance to pickup.
final Provider<AsyncValue<List<RiderDeliveryRequest>>> matchedNearbyDeliveryRequestsProvider =
    Provider<AsyncValue<List<RiderDeliveryRequest>>>((Ref ref) {
  final AsyncValue<List<RiderDeliveryRequest>> withDistance =
      ref.watch(openDeliveryRequestsProvider);
  final Set<String> dismissed =
      ref.watch(orderRequestSessionProvider).dismissedOrderIds;
  final RiderPosition? pos = ref.watch(riderPositionStreamProvider).valueOrNull;

  return withDistance.whenData((List<RiderDeliveryRequest> list) {
    return const DeliveryRequestMatcher().matchNearby(
      candidates: list,
      dismissedOrderIds: dismissed,
      riderLat: pos?.latitude,
      riderLng: pos?.longitude,
    );
  });
});
