import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/features/delivery_requests/data/rider_delivery_requests_repository.dart';
import 'package:mnd_rider/features/orders/presentation/providers/rider_active_order_provider.dart';

/// Coordinates + heading (degrees, 0-360, null if unknown) for the home map marker.
typedef RiderMapPosition = ({LatLng latLng, double? heading});

/// Best available rider coordinates for the home map (Firestore + device GPS).
final StreamProvider<RiderMapPosition?> riderMapLocationProvider =
    StreamProvider<RiderMapPosition?>((Ref ref) async* {
  final bool tracking = ref.watch(riderLocationTrackingEnabledProvider);

  if (tracking) {
    final LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    if (await Geolocator.isLocationServiceEnabled()) {
      try {
        final Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        yield (
          latLng: LatLng(pos.latitude, pos.longitude),
          heading: pos.heading,
        );
      } catch (_) {}
    }
  }

  final Stream<RiderPosition?> positionStream =
      ref.watch(riderDeliveryRequestsRepositoryProvider).watchRiderPosition();
  await for (final RiderPosition? pos in positionStream) {
    if (pos != null) {
      yield (
        latLng: LatLng(pos.latitude, pos.longitude),
        heading: pos.heading,
      );
    }
  }
});
