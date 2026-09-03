import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/features/rides/data/ride_directions_service.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_place.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/rides_providers.dart';

/// Cache key for a pickup→[stops]→dropoff driving route.
class RideRouteKey {
  const RideRouteKey(this.origin, this.destination, [this.stops = const <RidePlace>[]]);

  final RidePlace origin;
  final RidePlace destination;
  final List<RidePlace> stops;

  @override
  bool operator ==(Object other) {
    if (other is! RideRouteKey ||
        other.origin.lat != origin.lat ||
        other.origin.lng != origin.lng ||
        other.destination.lat != destination.lat ||
        other.destination.lng != destination.lng ||
        other.stops.length != stops.length) {
      return false;
    }
    for (int i = 0; i < stops.length; i++) {
      if (other.stops[i].lat != stops[i].lat ||
          other.stops[i].lng != stops[i].lng) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        origin.lat,
        origin.lng,
        destination.lat,
        destination.lng,
        Object.hashAll(
          stops.expand((RidePlace s) => <double>[s.lat, s.lng]),
        ),
      );
}

final AutoDisposeFutureProviderFamily<RideDrivingRoute?, RideRouteKey>
    rideDrivingRouteProvider =
    FutureProvider.autoDispose.family<RideDrivingRoute?, RideRouteKey>(
  (Ref ref, RideRouteKey key) async {
    return ref.read(rideDirectionsServiceProvider).fetchDrivingRoute(
          originLat: key.origin.lat,
          originLng: key.origin.lng,
          destLat: key.destination.lat,
          destLng: key.destination.lng,
          waypoints: <LatLng>[
            for (final RidePlace stop in key.stops) LatLng(stop.lat, stop.lng),
          ],
        );
  },
);

/// Convenience: route for the current booking draft (null if incomplete).
final Provider<AsyncValue<RideDrivingRoute?>> draftRideRouteProvider =
    Provider<AsyncValue<RideDrivingRoute?>>((Ref ref) {
  final RideBookingDraft draft = ref.watch(rideBookingDraftProvider);
  final RidePlace? pickup = draft.pickup;
  final RidePlace? dropoff = draft.dropoff;
  if (pickup == null || dropoff == null) {
    return const AsyncValue<RideDrivingRoute?>.data(null);
  }
  return ref.watch(
    rideDrivingRouteProvider(RideRouteKey(pickup, dropoff, draft.stops)),
  );
});

/// Cache key for a live-tracking route (moving rider → a fixed target).
/// Coordinates are rounded to 5dp (~1m) so GPS jitter on the same fix
/// doesn't churn the cache — real rider movement still misses and refetches.
class LiveRouteKey {
  LiveRouteKey({required LatLng origin, required this.destination})
      : origin = LatLng(
          double.parse(origin.latitude.toStringAsFixed(5)),
          double.parse(origin.longitude.toStringAsFixed(5)),
        );

  final LatLng origin;
  final LatLng destination;

  @override
  bool operator ==(Object other) =>
      other is LiveRouteKey &&
      other.origin == origin &&
      other.destination == destination;

  @override
  int get hashCode => Object.hash(origin, destination);
}

/// Driving route from a live-updating origin (e.g. a rider's GPS position)
/// to a fixed destination — used by live-tracking screens instead of the
/// pickup→dropoff route above.
final AutoDisposeFutureProviderFamily<RideDrivingRoute?, LiveRouteKey>
    liveRouteProvider =
    FutureProvider.autoDispose.family<RideDrivingRoute?, LiveRouteKey>(
  (Ref ref, LiveRouteKey key) {
    return ref.read(rideDirectionsServiceProvider).fetchDrivingRoute(
          originLat: key.origin.latitude,
          originLng: key.origin.longitude,
          destLat: key.destination.latitude,
          destLng: key.destination.longitude,
        );
  },
);

/// Road polyline points only — empty until Directions has loaded (no straight fallback).
List<LatLng> roadRoutePoints(RideDrivingRoute? route) {
  if (route != null && route.points.length >= 2) {
    return route.points;
  }
  return const <LatLng>[];
}

/// Camera bounds: prefer road polyline; otherwise the pins (incl. stops).
List<LatLng> fitBoundsPoints({
  required RidePlace pickup,
  required RidePlace dropoff,
  RideDrivingRoute? route,
  List<RidePlace> stops = const <RidePlace>[],
}) {
  final List<LatLng> road = roadRoutePoints(route);
  if (road.isNotEmpty) {
    return road;
  }
  return <LatLng>[
    LatLng(pickup.lat, pickup.lng),
    for (final RidePlace stop in stops) LatLng(stop.lat, stop.lng),
    LatLng(dropoff.lat, dropoff.lng),
  ];
}
