import 'dart:math' as math;

/// Client-side distance / estimate helpers (server quote remains source of truth).
class RideDistance {
  RideDistance._();

  static const double _earthRadiusKm = 6371.0088;

  /// Defaults when `ride_fare_config/rates` has not loaded yet.
  static const Map<String, RideFareRates> defaultFareTable =
      <String, RideFareRates>{
    'wheel': RideFareRates(baseLkr: 150, perKmLkr: 40, minLkr: 250, perStopLkr: 50),
    'bike': RideFareRates(baseLkr: 100, perKmLkr: 25, minLkr: 150, perStopLkr: 50),
    'car': RideFareRates(baseLkr: 200, perKmLkr: 50, minLkr: 400, perStopLkr: 100),
  };

  static double km(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final double phi1 = lat1 * math.pi / 180;
    final double phi2 = lat2 * math.pi / 180;
    final double dPhi = (lat2 - lat1) * math.pi / 180;
    final double dLambda = (lon2 - lon1) * math.pi / 180;

    final double a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dLambda / 2) *
            math.sin(dLambda / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double roundedKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return (km(lat1, lon1, lat2, lon2) * 10).round() / 10;
  }

  /// Straight-line distance across consecutive points (pickup, stops…, dropoff).
  /// Mirrors the server's multi-leg haversine summation in `rideFare.ts`.
  static double multiLegKm(List<({double lat, double lng})> points) {
    if (points.length < 2) {
      return 0;
    }
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += km(
        points[i].lat,
        points[i].lng,
        points[i + 1].lat,
        points[i + 1].lng,
      );
    }
    return total;
  }

  /// Instant fare estimate (not bookable until Cloud Function quote).
  static int estimateFareLkr(
    String vehicleType,
    double distanceKm, {
    Map<String, RideFareRates>? fareTable,
    int stopCount = 0,
  }) {
    final Map<String, RideFareRates> table =
        fareTable ?? defaultFareTable;
    final RideFareRates? rates = table[vehicleType.trim().toLowerCase()];
    if (rates == null || !distanceKm.isFinite || distanceKm < 0) {
      return rates?.minLkr ?? 0;
    }
    final int raw = rates.baseLkr +
        (distanceKm * rates.perKmLkr).ceil() +
        stopCount * rates.perStopLkr;
    return math.max(rates.minLkr, raw);
  }

  /// Rough ETA minutes assuming average road speed by vehicle (display only).
  static int etaMinutes(String vehicleType, double distanceKm) {
    final double speedKmh = switch (vehicleType) {
      'bike' => 28,
      'car' => 32,
      _ => 25,
    };
    if (distanceKm <= 0 || speedKmh <= 0) {
      return 0;
    }
    return math.max(1, (distanceKm / speedKmh * 60).round());
  }
}

class RideFareRates {
  const RideFareRates({
    required this.baseLkr,
    required this.perKmLkr,
    required this.minLkr,
    this.perStopLkr = 0,
  });

  final int baseLkr;
  final int perKmLkr;
  final int minLkr;

  /// Surcharge added per intermediate stop. Falls back to 0 for
  /// `ride_fare_config/rates` docs written before this field existed.
  final int perStopLkr;

  factory RideFareRates.fromMap(Map<String, dynamic>? data) {
    final Map<String, dynamic> m = data ?? <String, dynamic>{};
    return RideFareRates(
      baseLkr: (m['baseLkr'] as num?)?.toInt() ?? 0,
      perKmLkr: (m['perKmLkr'] as num?)?.toInt() ?? 0,
      minLkr: (m['minLkr'] as num?)?.toInt() ?? 0,
      perStopLkr: (m['perStopLkr'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isValid =>
      baseLkr >= 0 && perKmLkr >= 0 && minLkr >= 0 && perStopLkr >= 0;
}

class RideFareConfig {
  const RideFareConfig({required this.rates});

  final Map<String, RideFareRates> rates;

  static RideFareConfig get defaults =>
      RideFareConfig(rates: RideDistance.defaultFareTable);

  factory RideFareConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return RideFareConfig.defaults;
    }
    final Map<String, RideFareRates> rates = <String, RideFareRates>{};
    for (final String key in <String>['bike', 'wheel', 'car']) {
      final Object? raw = data[key];
      if (raw is Map) {
        final RideFareRates parsed =
            RideFareRates.fromMap(Map<String, dynamic>.from(raw));
        if (parsed.isValid) {
          rates[key] = parsed;
        }
      }
    }
    if (rates.length < 3) {
      return RideFareConfig(
        rates: <String, RideFareRates>{
          ...RideDistance.defaultFareTable,
          ...rates,
        },
      );
    }
    return RideFareConfig(rates: rates);
  }
}
