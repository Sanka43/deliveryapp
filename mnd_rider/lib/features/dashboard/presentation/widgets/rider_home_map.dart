import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/services/maps/rider_map_markers.dart';
import 'package:mnd_rider/core/services/maps/rider_map_styles.dart';
import 'package:mnd_rider/core/services/maps/rider_maps_helper.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_map_location_provider.dart';

/// Full-bleed Google Map with rider position marker.
class RiderHomeMap extends ConsumerStatefulWidget {
  const RiderHomeMap({
    super.key,
    this.bottomPadding = 168,
    this.topPadding = 96,
    this.vehicleType,
    this.onControllerReady,
  });

  final double bottomPadding;
  final double topPadding;

  /// Picks which top-down vehicle icon marks the rider on the map.
  final RiderVehicleType? vehicleType;
  final ValueChanged<GoogleMapController>? onControllerReady;

  @override
  ConsumerState<RiderHomeMap> createState() => _RiderHomeMapState();
}

class _RiderHomeMapState extends ConsumerState<RiderHomeMap> {
  GoogleMapController? _controller;
  LatLng? _lastTarget;
  BitmapDescriptor _selfIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  static const LatLng _defaultCenter = LatLng(6.9271, 79.8612);

  RiderVehicleType get _vehicleType => widget.vehicleType ?? RiderVehicleType.bike;

  @override
  void initState() {
    super.initState();
    _loadMarker();
  }

  Future<void> _loadMarker() async {
    final BitmapDescriptor icon = await RiderMapMarkers.load(_vehicleType);
    if (!mounted) {
      return;
    }
    setState(() => _selfIcon = icon);
  }

  void _moveCamera(LatLng target, {bool force = false}) {
    if (_controller == null) {
      return;
    }
    if (!force &&
        _lastTarget != null &&
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
  void didUpdateWidget(covariant RiderHomeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bottomPadding != widget.bottomPadding ||
        oldWidget.topPadding != widget.topPadding) {
      // Padding change repositions the visible map region without a rebuild marker.
      setState(() {});
    }
    if (oldWidget.vehicleType != widget.vehicleType) {
      _loadMarker();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RiderMapPosition?> location =
        ref.watch(riderMapLocationProvider);
    final RiderMapPosition? position = location.valueOrNull;
    final LatLng target = position?.latLng ?? _defaultCenter;
    final double? rawHeading = position?.heading;
    final double heading =
        (rawHeading != null && rawHeading >= 0) ? rawHeading : 0;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<AsyncValue<RiderMapPosition?>>(riderMapLocationProvider, (
      _,
      AsyncValue<RiderMapPosition?> next,
    ) {
      final LatLng? pos = next.valueOrNull?.latLng;
      if (pos != null) {
        _moveCamera(pos);
      }
    });

    return GoogleMap(
      initialCameraPosition: RiderMapsHelper.cameraFor(target, zoom: 14.5),
      style: dark ? RiderMapStyles.dark : null,
      onMapCreated: (GoogleMapController c) {
        _controller = c;
        widget.onControllerReady?.call(c);
        _moveCamera(target, force: true);
      },
      // Custom top-down vehicle icon is the rider marker — hide the default blue Google dot.
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: false,
      markers: RiderMapsHelper.singleMarker(
        id: 'rider_home',
        position: target,
        title: 'You',
        icon: _selfIcon,
        rotation: heading,
        flat: true,
      ),
      padding: EdgeInsets.only(
        top: widget.topPadding,
        bottom: widget.bottomPadding,
      ),
    );
  }
}
