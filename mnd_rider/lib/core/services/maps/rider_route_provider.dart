import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/services/maps/rider_directions_service.dart';

/// Cache key for an origin→destination driving route.
class RiderRouteKey {
  const RiderRouteKey(this.origin, this.destination);

  final LatLng origin;
  final LatLng destination;

  @override
  bool operator ==(Object other) {
    return other is RiderRouteKey &&
        other.origin.latitude == origin.latitude &&
        other.origin.longitude == origin.longitude &&
        other.destination.latitude == destination.latitude &&
        other.destination.longitude == destination.longitude;
  }

  @override
  int get hashCode => Object.hash(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );
}

final AutoDisposeFutureProviderFamily<RiderDrivingRoute?, RiderRouteKey>
    riderDrivingRouteProvider =
    FutureProvider.autoDispose.family<RiderDrivingRoute?, RiderRouteKey>(
  (Ref ref, RiderRouteKey key) async {
    return ref.read(riderDirectionsServiceProvider).fetchDrivingRoute(
          originLat: key.origin.latitude,
          originLng: key.origin.longitude,
          destLat: key.destination.latitude,
          destLng: key.destination.longitude,
        );
  },
);

/// Snaps a live-moving point to a coarse grid so the rider's leg only
/// re-requests a road route every ~100m of travel, not on every GPS tick.
LatLng riderRouteAnchor(LatLng point) {
  const double gridStep = 0.001;
  return LatLng(
    (point.latitude / gridStep).round() * gridStep,
    (point.longitude / gridStep).round() * gridStep,
  );
}

/// Road polyline points only — empty until Directions has loaded.
List<LatLng> riderRoadRoutePoints(RiderDrivingRoute? route) {
  if (route != null && route.points.length >= 2) {
    return route.points;
  }
  return const <LatLng>[];
}
