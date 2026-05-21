import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/services/maps/rider_maps_helper.dart';

/// Embedded Google Map for active trip step.
class RiderTripMap extends StatelessWidget {
  const RiderTripMap({
    super.key,
    required this.target,
    required this.markerTitle,
    this.height = 220,
  });

  final LatLng target;
  final String markerTitle;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: GoogleMap(
          initialCameraPosition: RiderMapsHelper.cameraFor(target),
          markers: RiderMapsHelper.singleMarker(
            id: 'trip_target',
            position: target,
            title: markerTitle,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
      ),
    );
  }
}
