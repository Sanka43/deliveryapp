import 'package:geolocator/geolocator.dart';

/// Geo helpers for rider ↔ pickup ↔ dropoff matching.
class GeoDistance {
  GeoDistance._();

  static double? kmBetween({
    required double? fromLat,
    required double? fromLng,
    required double? toLat,
    required double? toLng,
  }) {
    if (fromLat == null ||
        fromLng == null ||
        toLat == null ||
        toLng == null) {
      return null;
    }
    if (fromLat == 0 && fromLng == 0) {
      return null;
    }
    if (toLat == 0 && toLng == 0) {
      return null;
    }
    final double meters = Geolocator.distanceBetween(
      fromLat,
      fromLng,
      toLat,
      toLng,
    );
    return meters / 1000.0;
  }

  static double formatKm(double? km) {
    if (km == null || km.isNaN || km.isInfinite) {
      return 0;
    }
    if (km < 10) {
      return (km * 10).round() / 10.0;
    }
    return km.roundToDouble();
  }

  static String kmLabel(double? km) {
    final double v = formatKm(km);
    if (v <= 0) {
      return '—';
    }
    return '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} km';
  }
}
