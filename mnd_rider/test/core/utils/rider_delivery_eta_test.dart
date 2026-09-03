import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_rider/core/utils/rider_delivery_eta.dart';

void main() {
  group('RiderDeliveryEta.haversineKm', () {
    test('returns zero for identical points', () {
      expect(
        RiderDeliveryEta.haversineKm(6.9344, 79.8428, 6.9344, 79.8428),
        closeTo(0, 0.001),
      );
    });

    test('computes a plausible distance between two known points', () {
      // Colombo Fort to Kandy is roughly 90-100km as the crow flies.
      final double km =
          RiderDeliveryEta.haversineKm(6.9344, 79.8428, 7.2906, 80.6337);
      expect(km, inInclusiveRange(85, 100));
    });
  });

  group('RiderDeliveryEta.travelDuration', () {
    test('returns null for a non-positive average speed', () {
      expect(
        RiderDeliveryEta.travelDuration(
          fromLat: 6.9344,
          fromLng: 79.8428,
          toLat: 7.2906,
          toLng: 80.6337,
          averageSpeedKmh: 0,
        ),
        isNull,
      );
    });

    test('returns Duration.zero once within the arrived threshold', () {
      final Duration? d = RiderDeliveryEta.travelDuration(
        fromLat: 6.9344,
        fromLng: 79.8428,
        toLat: 6.9344,
        toLng: 79.8428,
      );
      expect(d, Duration.zero);
    });

    test('estimates duration from distance and average speed', () {
      // 24km at the default 24km/h average speed should take ~1 hour.
      final Duration? d = RiderDeliveryEta.travelDuration(
        fromLat: 0,
        fromLng: 0,
        toLat: 0,
        toLng: 0.2158, // ~24km east along the equator.
      );
      expect(d, isNotNull);
      expect(d!.inMinutes, inInclusiveRange(55, 65));
    });

    test('clamps duration to 24 hours for extreme distances', () {
      final Duration? d = RiderDeliveryEta.travelDuration(
        fromLat: -90,
        fromLng: 0,
        toLat: 90,
        toLng: 0,
        averageSpeedKmh: 0.001,
      );
      expect(d, Duration(seconds: 86400));
    });
  });

  group('RiderDeliveryEta.formatDuration', () {
    test('shows an em dash for null', () {
      expect(RiderDeliveryEta.formatDuration(null), '—');
    });

    test('shows "Arriving now" for zero duration', () {
      expect(RiderDeliveryEta.formatDuration(Duration.zero), 'Arriving now');
    });

    test('shows "< 1 min" for sub-minute durations', () {
      expect(
        RiderDeliveryEta.formatDuration(const Duration(seconds: 30)),
        '< 1 min',
      );
    });

    test('shows minutes under an hour', () {
      expect(
        RiderDeliveryEta.formatDuration(const Duration(minutes: 12)),
        '~12 min',
      );
    });

    test('shows hours with no remainder cleanly', () {
      expect(
        RiderDeliveryEta.formatDuration(const Duration(hours: 2)),
        '~2 h',
      );
    });

    test('shows hours and minutes together', () {
      expect(
        RiderDeliveryEta.formatDuration(const Duration(hours: 2, minutes: 15)),
        '~2 h 15 m',
      );
    });
  });

  group('RiderDeliveryEta.formatDistanceKm', () {
    test('shows an em dash for null/NaN/non-positive distances', () {
      expect(RiderDeliveryEta.formatDistanceKm(null), '—');
      expect(RiderDeliveryEta.formatDistanceKm(double.nan), '—');
      expect(RiderDeliveryEta.formatDistanceKm(0), '—');
      expect(RiderDeliveryEta.formatDistanceKm(-1), '—');
    });

    test('formats sub-kilometer distances in meters', () {
      expect(RiderDeliveryEta.formatDistanceKm(0.35), '350 m');
    });

    test('formats sub-10km distances with one decimal', () {
      expect(RiderDeliveryEta.formatDistanceKm(3.2), '3.2 km');
    });

    test('formats 10km+ distances as a whole number', () {
      expect(RiderDeliveryEta.formatDistanceKm(24.6), '25 km');
    });
  });
}
