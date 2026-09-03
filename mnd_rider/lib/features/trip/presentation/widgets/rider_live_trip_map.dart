import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/services/maps/rider_directions_service.dart';
import 'package:mnd_rider/core/services/maps/rider_map_markers.dart';
import 'package:mnd_rider/core/services/maps/rider_map_styles.dart';
import 'package:mnd_rider/core/services/maps/rider_maps_helper.dart';
import 'package:mnd_rider/core/services/maps/rider_route_provider.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_registration_provider.dart';
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
    this.isRide = false,
    this.stopPositions = const <LatLng>[],
    this.stopTitles = const <String>[],
    this.topPadding = 100,
    this.bottomPadding = 320,
  });

  final RiderTripPhase phase;
  final LatLng? vendorPosition;
  final LatLng? customerPosition;
  final String vendorTitle;
  final String customerTitle;

  /// True for a passenger ride leg: [vendorPosition] is the passenger's
  /// pickup point (not a shop), so it gets a pickup pin instead of the
  /// storefront badge used for delivery orders.
  final bool isRide;

  /// Intermediate stops (passenger rides only), in visit order — parallel
  /// to [stopTitles].
  final List<LatLng> stopPositions;
  final List<String> stopTitles;

  /// Screen space the top chrome / bottom sheet actually cover — without
  /// this, Google Maps treats the whole widget as visible map area and
  /// centers/fits markers behind those overlays instead of the sliver of
  /// map that's really on screen.
  final double topPadding;
  final double bottomPadding;

  @override
  ConsumerState<RiderLiveTripMap> createState() => _RiderLiveTripMapState();
}

class _RiderLiveTripMapState extends ConsumerState<RiderLiveTripMap> {
  GoogleMapController? _controller;
  bool _didFit = false;
  RiderVehicleType? _iconLoadedFor;

  void _loadRiderIcon(RiderVehicleType type) {
    if (_iconLoadedFor == type) {
      return;
    }
    _iconLoadedFor = type;
    RiderMapMarkers.load(type).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  bool _badgesRequested = false;

  void _loadDestinationBadges() {
    if (_badgesRequested) {
      return;
    }
    _badgesRequested = true;
    Future.wait(<Future<BitmapDescriptor>>[
      widget.isRide
          ? RiderMapMarkers.loadRidePickupBadge()
          : RiderMapMarkers.loadVendorBadge(),
      widget.isRide
          ? RiderMapMarkers.loadRideDropoffBadge()
          : RiderMapMarkers.loadCustomerBadge(),
    ]).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RiderLiveTripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Leg changed (e.g. picked up → heading to customer), or the sheet grew
    // (a collect-amount card appeared) — either way the old fit no longer
    // frames the right points in the right space, so re-fit.
    if (_navigationTargetOf(oldWidget) != _navigationTarget ||
        oldWidget.topPadding != widget.topPadding ||
        oldWidget.bottomPadding != widget.bottomPadding) {
      _didFit = false;
      _scheduleFit();
    }
  }

  LatLng? _navigationTargetOf(RiderLiveTripMap w) {
    final int? stopIndex = w.phase.stopIndex;
    if (stopIndex != null) {
      return stopIndex < w.stopPositions.length
          ? w.stopPositions[stopIndex]
          : null;
    }
    return w.phase.isVendorLeg ? w.vendorPosition : w.customerPosition;
  }

  LatLng? get _navigationTarget {
    final int? stopIndex = widget.phase.stopIndex;
    if (stopIndex != null) {
      return stopIndex < widget.stopPositions.length
          ? widget.stopPositions[stopIndex]
          : null;
    }
    if (widget.phase.isVendorLeg) {
      return widget.vendorPosition;
    }
    return widget.customerPosition;
  }

  /// Full ordered route: vendor → stops → customer (whichever ends exist).
  List<LatLng> get _routeWaypoints => <LatLng>[
    if (widget.vendorPosition != null) widget.vendorPosition!,
    ...widget.stopPositions,
    if (widget.customerPosition != null) widget.customerPosition!,
  ];

  void _scheduleFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
  }

  /// Frames the *active leg only* (rider → current target) rather than the
  /// whole multi-stop order — fitting the far-off next leg too zooms out so
  /// far that the leg actually being driven shrinks to an invisible sliver.
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
    final LatLng? target = _navigationTarget;
    if (target != null) {
      points.add(target);
    }
    if (points.isEmpty) {
      return;
    }
    if (points.length == 1) {
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          RiderMapsHelper.cameraFor(points.first, zoom: 16),
        ),
      );
    } else {
      await RiderMapsHelper.animateToFit(c, points, padding: 96);
    }
    _didFit = true;
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? rider = ref.watch(riderTripMapPositionProvider);
    final LatLng? target = _navigationTarget;
    final RiderVehicleType vehicleType =
        ref.watch(riderAuthProfileProvider).valueOrNull?.vehicleType ??
        RiderVehicleType.bike;
    _loadRiderIcon(vehicleType);
    _loadDestinationBadges();

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
      style: Theme.of(context).brightness == Brightness.dark
          ? RiderMapStyles.dark
          : null,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      padding: EdgeInsets.only(
        top: widget.topPadding,
        bottom: widget.bottomPadding,
      ),
      markers: _buildMarkers(rider, vehicleType),
      polylines: _buildPolylines(rider),
    );
  }

  Set<Marker> _buildMarkers(LatLng? rider, RiderVehicleType vehicleType) {
    final Set<Marker> markers = <Marker>{};
    if (rider != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: rider,
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: 'You'),
          icon: RiderMapMarkers.iconFor(vehicleType),
        ),
      );
    }
    if (widget.vendorPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('vendor'),
          position: widget.vendorPosition!,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: widget.vendorTitle),
          icon: widget.isRide
              ? RiderMapMarkers.ridePickupBadge
              : RiderMapMarkers.vendorBadge,
        ),
      );
    }
    if (widget.customerPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: widget.customerPosition!,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(title: widget.customerTitle),
          icon: widget.isRide
              ? RiderMapMarkers.rideDropoffBadge
              : RiderMapMarkers.customerBadge,
        ),
      );
    }
    for (int i = 0; i < widget.stopPositions.length; i++) {
      final String title = i < widget.stopTitles.length
          ? widget.stopTitles[i]
          : 'Stop ${i + 1}';
      markers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: widget.stopPositions[i],
          infoWindow: InfoWindow(title: title),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
        ),
      );
    }
    return markers;
  }

  /// Road-following points for [from]→[to], or the straight fallback while
  /// the Directions call is loading, fails, or no API key is configured.
  List<LatLng> _roadPoints(LatLng from, LatLng to) {
    final AsyncValue<RiderDrivingRoute?> route = ref.watch(
      riderDrivingRouteProvider(RiderRouteKey(from, to)),
    );
    final List<LatLng> road = riderRoadRoutePoints(route.valueOrNull);
    if (road.isNotEmpty) {
      return road;
    }
    return RiderMapsHelper.polylinePoints(from, to);
  }

  /// Rider's live leg: the Directions request is keyed off a coarse,
  /// snapped anchor (so it isn't re-fetched on every GPS tick), but the
  /// drawn line still starts exactly at the rider's true position.
  List<LatLng> _activeRoutePoints(LatLng rider, LatLng target) {
    final AsyncValue<RiderDrivingRoute?> route = ref.watch(
      riderDrivingRouteProvider(RiderRouteKey(riderRouteAnchor(rider), target)),
    );
    final List<LatLng> road = riderRoadRoutePoints(route.valueOrNull);
    if (road.isEmpty) {
      return RiderMapsHelper.polylinePoints(rider, target);
    }
    return <LatLng>[rider, ...road];
  }

  Set<Polyline> _buildPolylines(LatLng? rider) {
    final Set<Polyline> lines = <Polyline>{};
    final LatLng? vendor = widget.vendorPosition;
    final LatLng? customer = widget.customerPosition;
    final List<LatLng> waypoints = _routeWaypoints;

    // Full overview: vendor → stop(s) → customer, one dashed segment per leg.
    for (int i = 0; i < waypoints.length - 1; i++) {
      lines.add(
        Polyline(
          polylineId: PolylineId('overview_leg_$i'),
          color: Colors.black.withValues(alpha: 0.35),
          width: 3,
          patterns: <PatternItem>[PatternItem.dash(20), PatternItem.gap(12)],
          points: _roadPoints(waypoints[i], waypoints[i + 1]),
        ),
      );
    }

    if (rider != null && _navigationTarget != null) {
      final List<LatLng> activePoints = _activeRoutePoints(
        rider,
        _navigationTarget!,
      );
      // Casing + core, like turn-by-turn nav apps — the pale casing keeps
      // the route legible over both the light and dark map styles.
      lines.add(
        Polyline(
          polylineId: const PolylineId('active_route_casing'),
          color: Colors.white,
          width: 9,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          points: activePoints,
        ),
      );
      lines.add(
        Polyline(
          polylineId: const PolylineId('active_route'),
          color: Colors.black,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          points: activePoints,
        ),
      );
    } else if (vendor != null && customer != null && widget.phase.isVendorLeg) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('pickup_route'),
          color: AppColors.onlineGreen.withValues(alpha: 0.5),
          width: 3,
          patterns: <PatternItem>[PatternItem.dash(20), PatternItem.gap(12)],
          points: _roadPoints(vendor, customer),
        ),
      );
    }

    return lines;
  }
}
