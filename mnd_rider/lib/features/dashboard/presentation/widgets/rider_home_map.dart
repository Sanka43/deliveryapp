import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/services/maps/rider_maps_helper.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_map_location_provider.dart';

/// Full-screen Google Map with rider position marker.
class RiderHomeMap extends ConsumerStatefulWidget {
  const RiderHomeMap({super.key});

  @override
  ConsumerState<RiderHomeMap> createState() => _RiderHomeMapState();
}

class _RiderHomeMapState extends ConsumerState<RiderHomeMap> {
  GoogleMapController? _controller;
  LatLng? _lastTarget;

  static const LatLng _defaultCenter = LatLng(6.9271, 79.8612);

  void _moveCamera(LatLng target) {
    if (_controller == null) {
      return;
    }
    if (_lastTarget != null &&
        (_lastTarget!.latitude - target.latitude).abs() < 0.00008 &&
        (_lastTarget!.longitude - target.longitude).abs() < 0.00008) {
      return;
    }
    _lastTarget = target;
    _controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        RiderMapsHelper.cameraFor(target, zoom: 15.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LatLng?> location = ref.watch(riderMapLocationProvider);
    final LatLng target = location.valueOrNull ?? _defaultCenter;

    ref.listen<AsyncValue<LatLng?>>(riderMapLocationProvider, (_, AsyncValue<LatLng?> next) {
      final LatLng? pos = next.valueOrNull;
      if (pos != null) {
        _moveCamera(pos);
      }
    });

    return GoogleMap(
      initialCameraPosition: RiderMapsHelper.cameraFor(target, zoom: 14),
      onMapCreated: (GoogleMapController c) {
        _controller = c;
        _moveCamera(target);
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      markers: RiderMapsHelper.singleMarker(
        id: 'rider_home',
        position: target,
        title: 'You',
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      padding: const EdgeInsets.only(bottom: 340),
    );
  }
}
