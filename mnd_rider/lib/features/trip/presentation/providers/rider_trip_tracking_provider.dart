import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/utils/rider_delivery_eta.dart';
import 'package:mnd_rider/features/delivery_requests/data/rider_delivery_requests_repository.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/rider_delivery_requests_provider.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/trip/domain/rider_trip_phase.dart';

/// Device GPS stream for smooth map updates on the trip screen.
final StreamProvider<LatLng?> riderTripDevicePositionProvider =
    StreamProvider<LatLng?>((Ref ref) async* {
  final LocationPermission perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    return;
  }
  if (!await Geolocator.isLocationServiceEnabled()) {
    return;
  }

  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 8,
    ),
  ).map((Position p) => LatLng(p.latitude, p.longitude));
});

/// Best rider coordinate: device GPS, else Firestore `riders/{uid}`.
final Provider<LatLng?> riderTripMapPositionProvider = Provider<LatLng?>((Ref ref) {
  final LatLng? device = ref.watch(riderTripDevicePositionProvider).valueOrNull;
  if (device != null) {
    return device;
  }
  final RiderPosition? remote = ref.watch(riderPositionStreamProvider).valueOrNull;
  if (remote != null) {
    return LatLng(remote.latitude, remote.longitude);
  }
  return null;
});

class RiderTripEtaSnapshot {
  const RiderTripEtaSnapshot({
    required this.distanceKm,
    required this.duration,
    required this.label,
  });

  final double? distanceKm;
  final Duration? duration;
  final String label;

  String get distanceText => RiderDeliveryEta.formatDistanceKm(distanceKm);
  String get durationText => RiderDeliveryEta.formatDuration(duration);
}

final ProviderFamily<RiderTripEtaSnapshot, RiderTripEtaInput> riderTripEtaProvider =
    Provider.family<RiderTripEtaSnapshot, RiderTripEtaInput>((Ref ref, RiderTripEtaInput input) {
  final LatLng? rider = ref.watch(riderTripMapPositionProvider);
  final LatLng? target = input.target;
  if (rider == null || target == null) {
    return RiderTripEtaSnapshot(
      distanceKm: null,
      duration: null,
      label: input.label,
    );
  }
  final double km = RiderDeliveryEta.haversineKm(
    rider.latitude,
    rider.longitude,
    target.latitude,
    target.longitude,
  );
  final Duration? duration = RiderDeliveryEta.travelDuration(
    fromLat: rider.latitude,
    fromLng: rider.longitude,
    toLat: target.latitude,
    toLng: target.longitude,
  );
  return RiderTripEtaSnapshot(
    distanceKm: km,
    duration: duration,
    label: input.label,
  );
});

class RiderTripEtaInput {
  const RiderTripEtaInput({
    required this.target,
    required this.label,
  });

  final LatLng? target;
  final String label;

  @override
  bool operator ==(Object other) {
    return other is RiderTripEtaInput &&
        other.label == label &&
        other.target?.latitude == target?.latitude &&
        other.target?.longitude == target?.longitude;
  }

  @override
  int get hashCode => Object.hash(label, target?.latitude, target?.longitude);
}

/// Initial phase from Firestore order status.
RiderTripPhase riderTripPhaseFromOrder(RiderOrderDetail order) {
  switch (order.status) {
    case 'picked_up':
      return RiderTripPhase.navigateToCustomer;
    case 'on_the_way':
      return RiderTripPhase.navigateToCustomer;
    case 'delivered':
      return RiderTripPhase.atCustomer;
    default:
      return RiderTripPhase.navigateToVendor;
  }
}
