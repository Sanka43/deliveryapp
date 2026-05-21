import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/services/maps/rider_maps_helper.dart';
import 'package:mnd_rider/features/trip/domain/rider_trip_phase.dart';
import 'package:mnd_rider/features/trip/presentation/providers/rider_trip_tracking_provider.dart';

/// Full-screen live map: rider, vendor, customer markers + route polylines.
class RiderLiveTripMap extends ConsumerStatefulWidget {
  const RiderLiveTripMap({
    super.key,
    required this.phase,
    required this.vendorPosition,
    required this.customerPosition,
    required this.vendorTitle,
    required this.customerTitle,
  });

  final RiderTripPhase phase;
  final LatLng? vendorPosition;
  final LatLng? customerPosition;
  final String vendorTitle;
  final String customerTitle;

  @override
  ConsumerState<RiderLiveTripMap> createState() => _RiderLiveTripMapState();
}

class _RiderLiveTripMapState extends ConsumerState<RiderLiveTripMap> {
  GoogleMapController? _controller;
  bool _didFit = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  LatLng? get _navigationTarget {
    if (widget.phase.isVendorLeg) {
      return widget.vendorPosition;
    }
    return widget.customerPosition;
  }

  void _scheduleFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
  }

  Future<void> _fitCamera() async {
    final GoogleMapController? c = _controller;
    if (c == null) {
      return;
    }
    final List<LatLng> points = <LatLng>[];
    final LatLng? rider = ref.read(riderTripMapPositionProvider);
    if (rider != null) {
      points.add(rider);
    }
    if (widget.vendorPosition != null) {
      points.add(widget.vendorPosition!);
    }
    if (widget.customerPosition != null) {
      points.add(widget.customerPosition!);
    }
    final LatLng? target = _navigationTarget;
    if (target != null) {
      points.add(target);
    }
    if (points.isEmpty) {
      return;
    }
    await RiderMapsHelper.animateToFit(c, points, padding: 88);
    _didFit = true;
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? rider = ref.watch(riderTripMapPositionProvider);
    final LatLng? target = _navigationTarget;

    ref.listen<LatLng?>(riderTripMapPositionProvider, (
      LatLng? _,
      LatLng? next,
    ) {
      if (next != null && _controller != null && _didFit) {
        _controller!.animateCamera(CameraUpdate.newLatLng(next));
      }
    });

    if (!_didFit && (rider != null || target != null)) {
      _scheduleFit();
    }

    return GoogleMap(
      onMapCreated: (GoogleMapController c) {
        _controller = c;
        _didFit = false;
        _scheduleFit();
      },
      initialCameraPosition: RiderMapsHelper.cameraFor(
        rider ?? target ?? const LatLng(6.9271, 79.8612),
        zoom: 14,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      markers: _buildMarkers(rider),
      polylines: _buildPolylines(rider),
    );
  }

  Set<Marker> _buildMarkers(LatLng? rider) {
    final Set<Marker> markers = <Marker>{};
    if (rider != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: rider,
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
    if (widget.vendorPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('vendor'),
          position: widget.vendorPosition!,
          infoWindow: InfoWindow(title: widget.vendorTitle),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }
    if (widget.customerPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: widget.customerPosition!,
          infoWindow: InfoWindow(title: widget.customerTitle),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _buildPolylines(LatLng? rider) {
    final Set<Polyline> lines = <Polyline>{};
    final LatLng? vendor = widget.vendorPosition;
    final LatLng? customer = widget.customerPosition;

    if (vendor != null && customer != null) {
      lines.addAll(
        RiderMapsHelper.routePolyline(
          id: 'vendor_to_customer',
          from: vendor,
          to: customer,
          color: AppColors.primaryBlue.withValues(alpha: 0.35),
          width: 3,
          dashed: true,
        ),
      );
    }

    if (rider != null && _navigationTarget != null) {
      lines.addAll(
        RiderMapsHelper.routePolyline(
          id: 'active_route',
          from: rider,
          to: _navigationTarget!,
          color: AppColors.primaryBlue,
          width: 5,
        ),
      );
    } else if (vendor != null && customer != null && widget.phase.isVendorLeg) {
      lines.addAll(
        RiderMapsHelper.routePolyline(
          id: 'pickup_route',
          from: vendor,
          to: customer,
          color: AppColors.onlineGreen.withValues(alpha: 0.5),
          width: 3,
          dashed: true,
        ),
      );
    }

    return lines;
  }
}
