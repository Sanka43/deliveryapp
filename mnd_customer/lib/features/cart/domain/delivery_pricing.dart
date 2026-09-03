import 'dart:math' as math;

/// Straight-line distance (km) and LKR delivery fee from that distance.
///
/// Vendor documents should include either a GeoPoint field `location` or
/// numeric `latitude` / `longitude` so the fee can be computed from the store
/// to the customer's map-picked drop-off (stored on [CartState]).
class DeliveryPricing {
  DeliveryPricing._();

  /// Used when store coordinates, drop-off coordinates, or loading state
  /// prevents a distance-based quote.
  static const int fallbackFlatLkr = 180;

  /// First [includedKm] are covered by [minimumFeeLkr].
  static const double includedKm = 1.5;

  static const int minimumFeeLkr = 120;
  static const int perKmAfterIncludedLkr = 42;
  static const int maxFeeLkr = 850;

  /// Earth radius in kilometres (WGS84 mean).
  static const double _earthRadiusKm = 6371.0088;

  /// Haversine great-circle distance in kilometres.
  static double distanceKm(
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

  /// Non-negative LKR fee from route distance (km), clamped.
  ///
  /// [minimumFeeLkrOverride] / [perKmAfterIncludedLkrOverride] let callers
  /// plug in the admin-tunable rates from `platform_config/fees`
  /// (see `PlatformFeeConfig`) instead of the code defaults above.
  static int feeLkrForDistanceKm(
    double distanceKm, {
    int? minimumFeeLkrOverride,
    int? perKmAfterIncludedLkrOverride,
  }) {
    final int minFee = minimumFeeLkrOverride ?? minimumFeeLkr;
    final int perKm = perKmAfterIncludedLkrOverride ?? perKmAfterIncludedLkr;
    if (distanceKm.isNaN || distanceKm < 0) {
      return fallbackFlatLkr;
    }
    if (distanceKm <= includedKm) {
      return minFee;
    }
    final double extraKm = distanceKm - includedKm;
    final int fee = minFee + (extraKm * perKm).ceil();
    if (fee > maxFeeLkr) {
      return maxFeeLkr;
    }
    return fee;
  }
}

/// Client-side mirror of the backend's 5% platform service charge, used only
/// for the pre-order preview total — the server recomputes the authoritative
/// value from `subtotal` when the order is actually placed.
class ServiceChargePricing {
  ServiceChargePricing._();

  static const int percent = 5;

  /// [percentOverride] lets callers plug in the admin-tunable
  /// `serviceChargePercent` from `platform_config/fees`
  /// (see `PlatformFeeConfig`) instead of the code default above.
  static int serviceChargeLkr(int subtotalLkr, {num? percentOverride}) {
    if (subtotalLkr <= 0) {
      return 0;
    }
    final num pct = percentOverride ?? percent;
    return (subtotalLkr * pct / 100).floor();
  }
}
