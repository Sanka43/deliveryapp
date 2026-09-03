import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';

/// Top-down vehicle icons for a rider's *live position* marker (delivery
/// order tracking and ride-hailing trip tracking).
///
/// The source images point "up" (front toward the top) — the `Marker`'s
/// `rotation` then turns the icon to match the rider's actual GPS heading.
/// This is distinct from `RidesMapMarkers.vehicle()`, which draws a flat
/// tinted-silhouette-in-a-circle fleet pin for the ride booking/searching
/// screens.
class LiveVehicleMarkers {
  LiveVehicleMarkers._();

  static const Map<RideVehicleType, String> _assetPaths = <RideVehicleType, String>{
    RideVehicleType.bike: 'assets/vehicles/vehicle_bike.png',
    RideVehicleType.wheel: 'assets/vehicles/vehicle_three_wheeler.png',
    RideVehicleType.car: 'assets/vehicles/vehicle_car.png',
  };

  /// Natural size (px) of each source asset, so the marker is sized to
  /// [_targetHeight] without distorting its aspect ratio.
  static const Map<RideVehicleType, Size> _naturalSize = <RideVehicleType, Size>{
    RideVehicleType.bike: Size(223, 417),
    RideVehicleType.wheel: Size(267, 489),
    RideVehicleType.car: Size(276, 487),
  };

  static const double _targetHeight = 52;

  static final Map<RideVehicleType, BitmapDescriptor> _cache =
      <RideVehicleType, BitmapDescriptor>{};
  static final Map<RideVehicleType, Future<BitmapDescriptor>> _pending =
      <RideVehicleType, Future<BitmapDescriptor>>{};

  /// Best-effort synchronous icon for [type] — a generic pin until [load]
  /// has completed once for this vehicle type.
  static BitmapDescriptor iconFor(RideVehicleType? type) =>
      (type == null ? null : _cache[type]) ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  /// Loads (and caches) the top-down icon for [type].
  static Future<BitmapDescriptor> load(RideVehicleType type) {
    final BitmapDescriptor? cached = _cache[type];
    if (cached != null) {
      return Future<BitmapDescriptor>.value(cached);
    }
    return _pending[type] ??= _load(type).then((BitmapDescriptor icon) {
      _cache[type] = icon;
      return icon;
    });
  }

  static Future<BitmapDescriptor> _load(RideVehicleType type) async {
    final Size natural = _naturalSize[type] ?? const Size(240, 480);
    final double height = _targetHeight;
    final double width = height * (natural.width / natural.height);
    try {
      return await BitmapDescriptor.asset(
        const ImageConfiguration(),
        _assetPaths[type]!,
        width: width,
        height: height,
      );
    } catch (e, st) {
      debugPrint('LiveVehicleMarkers: failed to load ${_assetPaths[type]} for $type: $e\n$st');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }
}
