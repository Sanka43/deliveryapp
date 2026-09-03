/// Shop/food delivery fee curve (mirrors functions/src/deliveryFee.ts).
class DeliveryPricing {
  DeliveryPricing._();

  static const int fallbackFlatLkr = 180;
  static const double includedKm = 1.5;
  static const int minimumFeeLkr = 120;
  static const int perKmAfterIncludedLkr = 42;
  static const int maxFeeLkr = 850;

  /// Estimate / store→dropoff: ≤1.5 → 120; else curve; invalid → 180.
  static int feeLkrForDistanceKm(double distanceKm) {
    if (distanceKm.isNaN || distanceKm.isInfinite || distanceKm < 0) {
      return fallbackFlatLkr;
    }
    if (distanceKm <= includedKm) {
      return minimumFeeLkr;
    }
    final int fee =
        minimumFeeLkr + ((distanceKm - includedKm) * perKmAfterIncludedLkr).ceil();
    return fee > maxFeeLkr ? maxFeeLkr : fee;
  }

  /// Actual path fee: 0 / missing km → flat 180.
  static int feeLkrForActualTripKm(double distanceKm) {
    if (distanceKm.isNaN || distanceKm.isInfinite || distanceKm <= 0) {
      return fallbackFlatLkr;
    }
    return feeLkrForDistanceKm(distanceKm);
  }

  static double roundTraveledKm(double distanceKm) {
    if (distanceKm.isNaN || distanceKm.isInfinite || distanceKm < 0) {
      return 0;
    }
    return (distanceKm * 10).round() / 10.0;
  }
}
