import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_rider/core/utils/geo_distance.dart';

void main() {
  group('GeoDistance.kmBetween', () {
    test('returns null when any coordinate is missing', () {
      expect(
        GeoDistance.kmBetween(fromLat: null, fromLng: 1, toLat: 1, toLng: 1),
        isNull,
      );
      expect(
        GeoDistance.kmBetween(fromLat: 1, fromLng: 1, toLat: null, toLng: 1),
        isNull,
      );
    });

    test('treats (0, 0) as a missing-location sentinel', () {
      expect(
        GeoDistance.kmBetween(fromLat: 0, fromLng: 0, toLat: 6.9, toLng: 79.8),
        isNull,
      );
      expect(
        GeoDistance.kmBetween(fromLat: 6.9, fromLng: 79.8, toLat: 0, toLng: 0),
        isNull,
      );
    });

    test('computes a plausible distance between two known points', () {
      // Colombo Fort (~6.9344, 79.8428) to Kandy (~7.2906, 80.6337) is
      // roughly 90-100km as the crow flies.
      final double? km = GeoDistance.kmBetween(
        fromLat: 6.9344,
        fromLng: 79.8428,
        toLat: 7.2906,
        toLng: 80.6337,
      );
      expect(km, isNotNull);
      expect(km!, inInclusiveRange(85, 100));
    });

    test('returns zero for identical points', () {
      final double? km = GeoDistance.kmBetween(
        fromLat: 6.9344,
        fromLng: 79.8428,
        toLat: 6.9344,
        toLng: 79.8428,
      );
      expect(km, closeTo(0, 0.001));
    });
  });

  group('GeoDistance.formatKm', () {
    test('treats null/NaN/infinite as zero', () {
      expect(GeoDistance.formatKm(null), 0);
      expect(GeoDistance.formatKm(double.nan), 0);
      expect(GeoDistance.formatKm(double.infinity), 0);
    });

    test('rounds to one decimal under 10km', () {
      expect(GeoDistance.formatKm(3.14), 3.1);
      expect(GeoDistance.formatKm(9.96), 10.0);
    });

    test('rounds to a whole number at or above 10km', () {
      expect(GeoDistance.formatKm(10.4), 10);
      expect(GeoDistance.formatKm(24.6), 25);
    });
  });

  group('GeoDistance.kmLabel', () {
    test('shows an em dash for zero or negative distances', () {
      expect(GeoDistance.kmLabel(0), '—');
      expect(GeoDistance.kmLabel(-1), '—');
      expect(GeoDistance.kmLabel(null), '—');
    });

    test('formats sub-10km distances with one decimal', () {
      expect(GeoDistance.kmLabel(3.2), '3.2 km');
    });

    test('formats whole distances without a decimal', () {
      expect(GeoDistance.kmLabel(25), '25 km');
    });
  });
}
