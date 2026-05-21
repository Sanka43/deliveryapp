import 'dart:math' as math;

/// Rough ETA from straight-line distance and urban average speed (no routing API).
class RiderDeliveryEta {
  RiderDeliveryEta._();

  static const double defaultAverageSpeedKmh = 24;
  static const double arrivedThresholdKm = 0.035;

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

  static Duration? travelDuration({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    double averageSpeedKmh = defaultAverageSpeedKmh,
  }) {
    if (averageSpeedKmh <= 0) {
      return null;
    }
    final double km = haversineKm(fromLat, fromLng, toLat, toLng);
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

  static String formatDuration(Duration? d) {
    if (d == null) {
      return '—';
    }
    if (d == Duration.zero) {
      return 'Arriving now';
    }
    final int mins = d.inMinutes;
    if (mins < 1) {
      return '< 1 min';
    }
    if (mins < 60) {
      return '~$mins min';
    }
    final int h = mins ~/ 60;
    final int m = mins % 60;
    return m == 0 ? '~$h h' : '~$h h $m m';
  }

  static String formatDistanceKm(double? km) {
    if (km == null || km.isNaN || km <= 0) {
      return '—';
    }
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    }
    return '${km.round()} km';
  }
}
