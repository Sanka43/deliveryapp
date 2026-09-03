import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_snapshots.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_aggregate.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_line_item.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_period_snapshot.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';

RiderOrderDetail _order({
  required String id,
  required int deliveryFeeLkr,
  DateTime? createdAt,
}) {
  return RiderOrderDetail(
    id: id,
    status: 'delivered',
    storeName: 'Test Shop $id',
    vendorId: 'vendor_1',
    totalLkr: deliveryFeeLkr + 1000,
    deliveryFeeLkr: deliveryFeeLkr,
    items: const <RiderOrderLineItem>[],
    deliveryAddress: const RiderDeliveryAddress(
      line1: 'Line 1',
      line2: '',
      city: 'Colombo',
      phone: '0770000000',
    ),
    createdAt: createdAt,
  );
}

RiderPassengerTrip _trip({
  required String id,
  required int estimatedFareLkr,
  DateTime? createdAt,
}) {
  return RiderPassengerTrip(
    id: id,
    status: 'completed',
    vehicleType: 'tuk',
    estimatedFareLkr: estimatedFareLkr,
    distanceKm: 5,
    pickupLabel: 'Pickup $id',
    dropoffLabel: 'Dropoff $id',
    pickupLat: 6.9,
    pickupLng: 79.8,
    dropoffLat: 6.95,
    dropoffLng: 79.85,
    contactPhone: '0770000000',
    createdAt: createdAt,
  );
}

void main() {
  final DateTime now = DateTime.now();

  group('RiderEarningsSnapshots.daily', () {
    test('merges delivery and ride line items sorted by recency', () {
      final RiderEarningsPeriodSnapshot snapshot = RiderEarningsSnapshots.daily(
        orders: <RiderOrderDetail>[
          _order(id: 'o1', deliveryFeeLkr: 200, createdAt: now.subtract(const Duration(hours: 2))),
        ],
        trips: <RiderPassengerTrip>[
          _trip(id: 't1', estimatedFareLkr: 500, createdAt: now.subtract(const Duration(hours: 1))),
        ],
        aggregate: null,
      );

      expect(snapshot.lineItems, hasLength(2));
      // Most recent (the ride) first.
      expect(snapshot.lineItems.first.kind, RiderEarningsItemKind.ride);
      expect(snapshot.lineItems.last.kind, RiderEarningsItemKind.delivery);
    });

    test('excludes orders/trips completed before the start of today', () {
      final RiderEarningsPeriodSnapshot snapshot = RiderEarningsSnapshots.daily(
        orders: <RiderOrderDetail>[
          _order(id: 'old', deliveryFeeLkr: 200, createdAt: now.subtract(const Duration(days: 2))),
        ],
        trips: <RiderPassengerTrip>[
          _trip(id: 'old_ride', estimatedFareLkr: 500, createdAt: now.subtract(const Duration(days: 2))),
        ],
        aggregate: null,
      );

      expect(snapshot.lineItems, isEmpty);
      expect(snapshot.netTotal, 0);
      expect(snapshot.tripCount, 0);
    });

    test('prefers the server aggregate for netTotal/tripCount over the client sum', () {
      // Gross client sum would be 200 + 500 = 700 across 2 jobs; the
      // aggregate is commission-adjusted and must win.
      final RiderEarningsPeriodSnapshot snapshot = RiderEarningsSnapshots.daily(
        orders: <RiderOrderDetail>[
          _order(id: 'o1', deliveryFeeLkr: 200, createdAt: now),
        ],
        trips: <RiderPassengerTrip>[
          _trip(id: 't1', estimatedFareLkr: 500, createdAt: now),
        ],
        aggregate: const RiderEarningsAggregate(
          periodKey: 'daily_2026-01-01',
          periodType: RiderEarningsPeriodType.daily,
          totalLkr: 640,
          tripCount: 2,
        ),
      );

      expect(snapshot.netTotal, 640);
      expect(snapshot.tripCount, 2);
      // Line items are still built client-side for display.
      expect(snapshot.lineItems, hasLength(2));
    });

    test('falls back to the gross client sum while the aggregate is unavailable', () {
      final RiderEarningsPeriodSnapshot snapshot = RiderEarningsSnapshots.daily(
        orders: <RiderOrderDetail>[
          _order(id: 'o1', deliveryFeeLkr: 200, createdAt: now),
        ],
        trips: <RiderPassengerTrip>[
          _trip(id: 't1', estimatedFareLkr: 500, createdAt: now),
        ],
        aggregate: null,
      );

      expect(snapshot.netTotal, 700);
      expect(snapshot.tripCount, 2);
    });
  });
}
