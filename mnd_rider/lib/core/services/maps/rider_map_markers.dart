import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';

/// Custom map markers for the rider app.
///
/// The rider's own position is drawn as a top-down vehicle icon (bike /
/// three-wheeler / car·van) instead of a pin. The source images point "up"
/// (front toward the top) — [RiderMapsHelper.singleMarker]'s `rotation` then
/// turns the icon to match the rider's actual heading on the map.
class RiderMapMarkers {
  RiderMapMarkers._();

  static const Map<RiderVehicleType, String> _assetPaths =
      <RiderVehicleType, String>{
        RiderVehicleType.bike: 'assets/vehicles/vehicle_bike.png',
        RiderVehicleType.threeWheeler:
            'assets/vehicles/vehicle_three_wheeler.png',
        RiderVehicleType.car: 'assets/vehicles/vehicle_car.png',
        RiderVehicleType.van: 'assets/vehicles/vehicle_car.png',
      };

  /// Natural size (px) of each source asset, so the marker is sized to
  /// [_targetHeight] without distorting its aspect ratio.
  static const Map<RiderVehicleType, Size> _naturalSize =
      <RiderVehicleType, Size>{
        RiderVehicleType.bike: Size(223, 417),
        RiderVehicleType.threeWheeler: Size(267, 489),
        RiderVehicleType.car: Size(276, 487),
        RiderVehicleType.van: Size(276, 487),
      };

  static const double _targetHeight = 52;

  static final Map<RiderVehicleType, BitmapDescriptor> _cache =
      <RiderVehicleType, BitmapDescriptor>{};
  static final Map<RiderVehicleType, Future<BitmapDescriptor>> _pending =
      <RiderVehicleType, Future<BitmapDescriptor>>{};

  /// Best-effort synchronous icon for [type] — a generic pin until [load]
  /// has completed once for this vehicle type.
  static BitmapDescriptor iconFor(RiderVehicleType type) =>
      _cache[type] ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  /// Loads (and caches) the top-down icon for [type].
  static Future<BitmapDescriptor> load(RiderVehicleType type) {
    final BitmapDescriptor? cached = _cache[type];
    if (cached != null) {
      return Future<BitmapDescriptor>.value(cached);
    }
    return _pending[type] ??= _load(type).then((BitmapDescriptor icon) {
      _cache[type] = icon;
      return icon;
    });
  }

  static Future<BitmapDescriptor> _load(RiderVehicleType type) async {
    final Size natural = _naturalSize[type] ?? const Size(240, 480);
    final double height = _targetHeight;
    final double width = height * (natural.width / natural.height);
    final String asset =
        _assetPaths[type] ?? _assetPaths[RiderVehicleType.bike]!;
    try {
      return await BitmapDescriptor.asset(
        const ImageConfiguration(),
        asset,
        width: width,
        height: height,
      );
    } catch (e, st) {
      debugPrint('RiderMapMarkers: failed to load $asset for $type: $e\n$st');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  static BitmapDescriptor? _vendorBadge;
  static BitmapDescriptor? _customerBadge;
  static Future<BitmapDescriptor>? _pendingVendorBadge;
  static Future<BitmapDescriptor>? _pendingCustomerBadge;

  /// Best-effort synchronous store-pin icon — a generic pin until
  /// [loadVendorBadge] has completed once.
  static BitmapDescriptor get vendorBadge =>
      _vendorBadge ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);

  /// Best-effort synchronous drop-off pin icon — a generic pin until
  /// [loadCustomerBadge] has completed once.
  static BitmapDescriptor get customerBadge =>
      _customerBadge ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

  /// Rounded storefront glyph on a green disc — matches the STORE leg color
  /// used everywhere else on the trip screen (stepper, destination card).
  static Future<BitmapDescriptor> loadVendorBadge() {
    return _vendorBadge != null
        ? Future<BitmapDescriptor>.value(_vendorBadge)
        : _pendingVendorBadge ??=
              _drawBadge(
                icon: Icons.storefront_rounded,
                background: const Color(0xFF1B8A3E), // AppColors.pickupGreen
              ).then((BitmapDescriptor icon) {
                _vendorBadge = icon;
                return icon;
              });
  }

  /// Person glyph on a red disc — matches the CUSTOMER leg color used
  /// everywhere else on the trip screen (stepper, destination card).
  static Future<BitmapDescriptor> loadCustomerBadge() {
    return _customerBadge != null
        ? Future<BitmapDescriptor>.value(_customerBadge)
        : _pendingCustomerBadge ??=
              _drawBadge(
                icon: Icons.person_rounded,
                background: const Color(0xFFE03B2F), // AppColors.dropoffRed
              ).then((BitmapDescriptor icon) {
                _customerBadge = icon;
                return icon;
              });
  }

  static BitmapDescriptor? _ridePickupBadge;
  static BitmapDescriptor? _rideDropoffBadge;
  static Future<BitmapDescriptor>? _pendingRidePickupBadge;
  static Future<BitmapDescriptor>? _pendingRideDropoffBadge;

  /// Best-effort synchronous passenger-pickup pin — a generic pin until
  /// [loadRidePickupBadge] has completed once. Distinct from [vendorBadge]:
  /// a ride's pickup point is a passenger, not a shop.
  static BitmapDescriptor get ridePickupBadge =>
      _ridePickupBadge ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

  /// Best-effort synchronous ride drop-off pin — a generic pin until
  /// [loadRideDropoffBadge] has completed once.
  static BitmapDescriptor get rideDropoffBadge =>
      _rideDropoffBadge ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

  /// Person glyph on a green disc — a passenger ride's pickup point (no
  /// shop involved, unlike a delivery order's vendor leg).
  static Future<BitmapDescriptor> loadRidePickupBadge() {
    return _ridePickupBadge != null
        ? Future<BitmapDescriptor>.value(_ridePickupBadge)
        : _pendingRidePickupBadge ??=
              _drawBadge(
                icon: Icons.person_rounded,
                background: AppColors.pickupGreen,
              ).then((BitmapDescriptor icon) {
                _ridePickupBadge = icon;
                return icon;
              });
  }

  /// Flag glyph on a red disc — a passenger ride's drop-off point.
  static Future<BitmapDescriptor> loadRideDropoffBadge() {
    return _rideDropoffBadge != null
        ? Future<BitmapDescriptor>.value(_rideDropoffBadge)
        : _pendingRideDropoffBadge ??=
              _drawBadge(
                icon: Icons.flag_rounded,
                background: AppColors.dropoffRed,
              ).then((BitmapDescriptor icon) {
                _rideDropoffBadge = icon;
                return icon;
              });
  }

  /// Renders `icon` centered on a colored disc with a white contrast ring,
  /// matching the icon-avatar look already used in the trip bottom sheet's
  /// destination card — there's no bundled PNG for these, so draw one.
  static Future<BitmapDescriptor> _drawBadge({
    required IconData icon,
    required Color background,
  }) async {
    const double canvasSize = 96;
    const double radius = canvasSize / 2;
    const Offset center = Offset(radius, radius);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, canvasSize, canvasSize),
    );

    canvas.drawCircle(
      center.translate(0, 3),
      radius - 6,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(center, radius - 4, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius - 8, Paint()..color = background);

    final TextPainter painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: canvasSize * 0.42,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    painter.paint(
      canvas,
      center.translate(-painter.width / 2, -painter.height / 2),
    );

    final ui.Image image = await recorder.endRecording().toImage(
      canvasSize.toInt(),
      canvasSize.toInt(),
    );
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 40,
      height: 40,
    );
  }
}
