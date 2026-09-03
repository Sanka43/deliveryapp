import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_rider/core/utils/delivery_pricing.dart';

void main() {
  group('DeliveryPricing.feeLkrForDistanceKm', () {
    test('returns the minimum fee at or under the included distance', () {
      expect(DeliveryPricing.feeLkrForDistanceKm(0), 120);
      expect(DeliveryPricing.feeLkrForDistanceKm(1), 120);
      expect(DeliveryPricing.feeLkrForDistanceKm(1.5), 120);
    });

    test('adds the per-km rate, rounded up, beyond the included distance', () {
      // 3.5km -> 2km over included, ceil(2 * 42) = 84 -> 120 + 84 = 204.
      expect(DeliveryPricing.feeLkrForDistanceKm(3.5), 204);
      // 2.6km -> 1.1km over included, ceil(1.1 * 42) = 47 -> 120 + 47 = 167.
      expect(DeliveryPricing.feeLkrForDistanceKm(2.6), 167);
    });

    test('clamps to the max fee for long distances', () {
      expect(DeliveryPricing.feeLkrForDistanceKm(100), 850);
      expect(DeliveryPricing.feeLkrForDistanceKm(1000), 850);
    });

    test('falls back to the flat fee for invalid distances', () {
      expect(DeliveryPricing.feeLkrForDistanceKm(-1), 180);
      expect(DeliveryPricing.feeLkrForDistanceKm(double.nan), 180);
      expect(DeliveryPricing.feeLkrForDistanceKm(double.infinity), 180);
    });
  });

  group('DeliveryPricing.feeLkrForActualTripKm', () {
    test('falls back to the flat fee for zero, negative, or invalid distances', () {
      expect(DeliveryPricing.feeLkrForActualTripKm(0), 180);
      expect(DeliveryPricing.feeLkrForActualTripKm(-5), 180);
      expect(DeliveryPricing.feeLkrForActualTripKm(double.nan), 180);
      expect(DeliveryPricing.feeLkrForActualTripKm(double.infinity), 180);
    });

    test('delegates to the distance curve for positive distances', () {
      expect(
        DeliveryPricing.feeLkrForActualTripKm(3.5),
        DeliveryPricing.feeLkrForDistanceKm(3.5),
      );
    });
  });

  group('DeliveryPricing.roundTraveledKm', () {
    test('rounds to one decimal place', () {
      expect(DeliveryPricing.roundTraveledKm(3.14), 3.1);
      expect(DeliveryPricing.roundTraveledKm(3.16), 3.2);
    });

    test('treats invalid distances as zero', () {
      expect(DeliveryPricing.roundTraveledKm(-1), 0);
      expect(DeliveryPricing.roundTraveledKm(double.nan), 0);
      expect(DeliveryPricing.roundTraveledKm(double.infinity), 0);
    });
  });
}
