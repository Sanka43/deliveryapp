import 'package:mnd_rider/features/earnings/data/rider_earnings_aggregator.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_period_keys.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_aggregate.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_line_item.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_period_snapshot.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';

/// Builds each period tab shown on the earnings screen. The headline
/// net/trip-count prefer the server-computed [RiderEarningsAggregate]
/// (commission-adjusted, covers deliveries + rides); the activity list below
/// is always built client-side by merging delivered orders and completed
/// rides so individual jobs can be shown even before the aggregate exists.
abstract final class RiderEarningsSnapshots {
  static RiderEarningsPeriodSnapshot daily({
    required List<RiderOrderDetail> orders,
    required List<RiderPassengerTrip> trips,
    RiderEarningsAggregate? aggregate,
  }) {
    final DateTime startOfDay =
        RiderEarningsPeriodKeys.startOfDay(DateTime.now());
    return _period(
      rangeTitle: 'Today',
      rangeSubtitle: 'Deliveries & rides earned',
      orders: _ordersSince(orders, startOfDay),
      trips: _tripsSince(trips, startOfDay),
      aggregate: aggregate,
    );
  }

  static RiderEarningsPeriodSnapshot weekly({
    required List<RiderOrderDetail> orders,
    required List<RiderPassengerTrip> trips,
    RiderEarningsAggregate? aggregate,
  }) {
    final DateTime startOfWeek =
        RiderEarningsPeriodKeys.startOfWeek(DateTime.now());
    return _period(
      rangeTitle: 'This week',
      rangeSubtitle: 'Mon–Sun · deliveries & rides',
      orders: _ordersSince(orders, startOfWeek),
      trips: _tripsSince(trips, startOfWeek),
      aggregate: aggregate,
    );
  }

  static RiderEarningsPeriodSnapshot monthly({
    required List<RiderOrderDetail> orders,
    required List<RiderPassengerTrip> trips,
    RiderEarningsAggregate? aggregate,
  }) {
    final DateTime startOfMonth =
        RiderEarningsPeriodKeys.startOfMonth(DateTime.now());
    return _period(
      rangeTitle: 'This month',
      rangeSubtitle: 'Calendar month · deliveries & rides',
      orders: _ordersSince(orders, startOfMonth),
      trips: _tripsSince(trips, startOfMonth),
      aggregate: aggregate,
    );
  }

  static List<RiderOrderDetail> _ordersSince(
    List<RiderOrderDetail> all,
    DateTime start,
  ) {
    return all
        .where(
          (RiderOrderDetail o) =>
              !RiderEarningsAggregator.orderCompletedAt(o).isBefore(start),
        )
        .toList();
  }

  static List<RiderPassengerTrip> _tripsSince(
    List<RiderPassengerTrip> all,
    DateTime start,
  ) {
    return all
        .where(
          (RiderPassengerTrip t) =>
              !RiderEarningsAggregator.tripCompletedAt(t).isBefore(start),
        )
        .toList();
  }

  static RiderEarningsPeriodSnapshot _period({
    required String rangeTitle,
    required String rangeSubtitle,
    required List<RiderOrderDetail> orders,
    required List<RiderPassengerTrip> trips,
    required RiderEarningsAggregate? aggregate,
  }) {
    final List<RiderEarningsLineItem> lines = <RiderEarningsLineItem>[
      ...orders.map(
        (RiderOrderDetail o) => RiderEarningsLineItem(
          title: o.storeName,
          subtitle: o.referenceForDisplay,
          amount: o.deliveryFeeLkr.toDouble(),
          kind: RiderEarningsItemKind.delivery,
          completedAt: RiderEarningsAggregator.orderCompletedAt(o),
        ),
      ),
      ...trips.map(
        (RiderPassengerTrip t) => RiderEarningsLineItem(
          title: t.pickupLabel.isEmpty ? 'Ride' : t.pickupLabel,
          subtitle: t.dropoffLabel.isEmpty ? t.vehicleType : t.dropoffLabel,
          amount: t.estimatedFareLkr.toDouble(),
          kind: RiderEarningsItemKind.ride,
          completedAt: RiderEarningsAggregator.tripCompletedAt(t),
        ),
      ),
    ]..sort(
        (RiderEarningsLineItem a, RiderEarningsLineItem b) =>
            b.completedAt.compareTo(a.completedAt),
      );

    // Fallback only matters while the aggregate hasn't loaded yet or the
    // rider has no completed job this period (aggregate doc absent) — in
    // that second case the fallback sum is correctly zero anyway. It is
    // gross (not commission-adjusted), unlike the aggregate.
    final double fallbackNet = orders.fold<double>(
          0,
          (double s, RiderOrderDetail o) => s + o.deliveryFeeLkr,
        ) +
        trips.fold<double>(
          0,
          (double s, RiderPassengerTrip t) => s + t.estimatedFareLkr,
        );
    final int fallbackCount = orders.length + trips.length;

    return RiderEarningsPeriodSnapshot(
      rangeTitle: rangeTitle,
      rangeSubtitle: rangeSubtitle,
      netTotal: aggregate?.totalLkr ?? fallbackNet,
      tripCount: aggregate?.tripCount ?? fallbackCount,
      lineItems: lines.take(12).toList(growable: false),
    );
  }
}
