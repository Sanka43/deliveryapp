import 'dart:math' as math;

/// Rough ETA from rider position to drop-off using straight-line distance and an
/// assumed average urban delivery speed (no routing API — estimate only).
class RiderDeliveryEta {
  RiderDeliveryEta._();

  /// Typical mixed-traffic speed for ETA hint (km/h).
  static const double defaultAverageSpeedKmh = 24;

  /// Distance under this (km) shows as "Arriving soon".
  static const double arrivedThresholdKm = 0.035;

  /// Earth radius in km.
  static const double _earthRadiusKm = 6371;

  static double haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double _degToRad(double d) => d * math.pi / 180;

  /// Travel duration; null if coordinates invalid.
  static Duration? travelDuration({
    required double riderLat,
    required double riderLng,
    required double dropLat,
    required double dropLng,
    double averageSpeedKmh = defaultAverageSpeedKmh,
  }) {
    if (averageSpeedKmh <= 0) {
      return null;
    }
    final double km = haversineKm(riderLat, riderLng, dropLat, dropLng);
    if (km.isNaN || km.isInfinite) {
      return null;
    }
    if (km <= arrivedThresholdKm) {
      return Duration.zero;
    }
    final double hours = km / averageSpeedKmh;
    final int seconds = (hours * 3600).ceil().clamp(1, 86400);
    return Duration(seconds: seconds);
  }
}
