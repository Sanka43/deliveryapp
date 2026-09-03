import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/constants/app_fonts.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_theme.dart';
import 'package:mnd_delivery_app/features/rides/presentation/widgets/rides_vehicle_icon.dart';

/// Custom map markers with "Pick up" / "Drop" label chips + vehicle fleet pins.
class RidesMapMarkers {
  RidesMapMarkers._();

  static BitmapDescriptor? _pickup;
  static BitmapDescriptor? _dropoff;
  static final List<BitmapDescriptor?> _stops = <BitmapDescriptor?>[
    null,
    null,
  ];
  static final Map<RideVehicleType, BitmapDescriptor> _vehicles =
      <RideVehicleType, BitmapDescriptor>{};
  static Future<void>? _loading;

  static Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    final List<Object> built = await Future.wait(<Future<Object>>[
      _buildLabeledPin(
        label: 'Pick up',
        accent: const Color(RidesColors.pickupGreen),
      ),
      _buildLabeledPin(
        label: 'Drop',
        accent: const Color(RidesColors.dropoffRed),
      ),
      _buildLabeledPin(
        label: 'Stop 1',
        accent: const Color(RidesColors.stopAmber),
      ),
      _buildLabeledPin(
        label: 'Stop 2',
        accent: const Color(RidesColors.stopAmber),
      ),
      ...RideVehicleType.values.map(_buildVehiclePin),
    ]);
    _pickup = built[0] as BitmapDescriptor;
    _dropoff = built[1] as BitmapDescriptor;
    _stops[0] = built[2] as BitmapDescriptor;
    _stops[1] = built[3] as BitmapDescriptor;
    final List<RideVehicleType> types = RideVehicleType.values;
    for (int i = 0; i < types.length; i++) {
      _vehicles[types[i]] = built[4 + i] as BitmapDescriptor;
    }
  }

  static BitmapDescriptor get pickup =>
      _pickup ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

  static BitmapDescriptor get dropoff =>
      _dropoff ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

  /// Labeled "Stop 1" / "Stop 2" pin for [index] (0-based).
  static BitmapDescriptor stopAt(int index) =>
      (index >= 0 && index < _stops.length ? _stops[index] : null) ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);

  static BitmapDescriptor vehicle(RideVehicleType type) =>
      _vehicles[type] ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  static Future<BitmapDescriptor> _buildVehiclePin(RideVehicleType type) async {
    const double size = 112;
    const double iconSize = 56;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const Color accent = RidesColors.accentBlue;

    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 4,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 8,
      Paint()..color = accent,
    );

    // Not disposed until after the picture is actually rasterized below —
    // `drawImageRect` only *records* the draw call here; disposing `raw`
    // immediately (before `toImage()` rasterizes the recording) freed its
    // GPU-side pixel data before Skia ever read it, so the later texture
    // upload picked up detached memory and produced garbage on the canvas
    // (surfaced as "WebGL: INVALID_VALUE: texImage2D: The source data has
    // been detached" in the browser console) — a corrupted rectangle
    // sharing the GPU context, not anything Google Maps or the Flutter web
    // renderer was doing wrong.
    ui.Image? raw;
    try {
      final ByteData data =
          await rootBundle.load(RidesVehicleIcon.assetFor(type));
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: iconSize.toInt(),
        targetHeight: iconSize.toInt(),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      raw = frame.image;
      final Rect dst = Rect.fromLTWH(
        (size - iconSize) / 2,
        (size - iconSize) / 2,
        iconSize,
        iconSize,
      );
      canvas.drawImageRect(
        raw,
        Rect.fromLTWH(0, 0, raw.width.toDouble(), raw.height.toDouble()),
        dst,
        Paint()
          ..filterQuality = FilterQuality.high
          ..colorFilter = const ColorFilter.mode(
            Colors.white,
            BlendMode.srcIn,
          ),
      );
    } catch (_) {
      // Fallback: empty blue disc if asset fails.
    }

    final ui.Image image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    raw?.dispose();
    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    return BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: 48,
      height: 48,
    );
  }

  static Future<BitmapDescriptor> _buildLabeledPin({
    required String label,
    required Color accent,
  }) async {
    const double width = 160;
    const double height = 96;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: AppFonts.title,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width - 24);

    final double chipW = (textPainter.width + 28).clamp(72, width);
    final double chipH = textPainter.height + 16;
    final RRect chip = RRect.fromRectAndRadius(
      Rect.fromLTWH((width - chipW) / 2, 4, chipW, chipH),
      const Radius.circular(20),
    );

    canvas.drawRRect(chip, Paint()..color = accent);
    canvas.drawRRect(
      chip,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    textPainter.paint(
      canvas,
      Offset(
        (width - textPainter.width) / 2,
        4 + (chipH - textPainter.height) / 2,
      ),
    );

    final double pinTop = chipH + 8;
    final Path pin = Path()
      ..moveTo(width / 2, height - 4)
      ..quadraticBezierTo(
        width / 2 - 22,
        pinTop + 18,
        width / 2 - 18,
        pinTop + 8,
      )
      ..arcToPoint(
        Offset(width / 2 + 18, pinTop + 8),
        radius: const Radius.circular(18),
        clockwise: true,
      )
      ..quadraticBezierTo(
        width / 2 + 22,
        pinTop + 18,
        width / 2,
        height - 4,
      )
      ..close();

    canvas.drawPath(pin, Paint()..color = accent);
    canvas.drawCircle(
      Offset(width / 2, pinTop + 10),
      7,
      Paint()..color = Colors.white,
    );

    final ui.Image image = await recorder.endRecording().toImage(
          width.toInt(),
          height.toInt(),
        );
    final ByteData? bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      return BitmapDescriptor.defaultMarkerWithHue(
        accent.toARGB32() == const Color(RidesColors.pickupGreen).toARGB32()
            ? BitmapDescriptor.hueGreen
            : BitmapDescriptor.hueRed,
      );
    }
    final Uint8List png = bytes.buffer.asUint8List();
    return BitmapDescriptor.bytes(
      png,
      width: width / 2.6,
      height: height / 2.6,
    );
  }
}
