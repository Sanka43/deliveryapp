import 'package:mnd_rider/features/earnings/data/rider_earnings_aggregator.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_period_keys.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_line_item.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_period_snapshot.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

abstract final class RiderEarningsSnapshots {
  static RiderEarningsPeriodSnapshot dailyFromOrders(
    List<RiderOrderDetail> all,
  ) {
    final DateTime startOfDay =
        RiderEarningsPeriodKeys.startOfDay(DateTime.now());
    final List<RiderOrderDetail> orders = all
        .where(
          (RiderOrderDetail o) => !RiderEarningsAggregator.orderCompletedAt(o)
              .isBefore(startOfDay),
        )
        .toList();
    return _period(
      rangeTitle: 'Today',
      rangeSubtitle: 'Delivery fees earned',
      orders: orders,
    );
  }

  static RiderEarningsPeriodSnapshot weeklyFromOrders(
    List<RiderOrderDetail> all,
  ) {
    final DateTime startOfWeek =
        RiderEarningsPeriodKeys.startOfWeek(DateTime.now());
    final List<RiderOrderDetail> orders = all
        .where(
          (RiderOrderDetail o) => !RiderEarningsAggregator.orderCompletedAt(o)
              .isBefore(startOfWeek),
        )
        .toList();
    return _period(
      rangeTitle: 'This week',
      rangeSubtitle: 'Mon–Sun · delivery fees',
      orders: orders,
    );
  }

  static RiderEarningsPeriodSnapshot monthlyFromOrders(
    List<RiderOrderDetail> all,
  ) {
    final DateTime startOfMonth =
        RiderEarningsPeriodKeys.startOfMonth(DateTime.now());
    final List<RiderOrderDetail> orders = all
        .where(
          (RiderOrderDetail o) => !RiderEarningsAggregator.orderCompletedAt(o)
              .isBefore(startOfMonth),
        )
        .toList();
    return _period(
      rangeTitle: 'This month',
      rangeSubtitle: 'Calendar month · delivery fees',
      orders: orders,
    );
  }

  static RiderEarningsPeriodSnapshot _period({
    required String rangeTitle,
    required String rangeSubtitle,
    required List<RiderOrderDetail> orders,
  }) {
    final double net =
        orders.fold<double>(0, (double s, RiderOrderDetail o) => s + o.deliveryFeeLkr);
    final List<RiderEarningsLineItem> lines = orders
        .take(12)
        .map(
          (RiderOrderDetail o) => RiderEarningsLineItem(
            title: o.storeName,
            subtitle: o.referenceForDisplay,
            amount: o.deliveryFeeLkr.toDouble(),
          ),
        )
        .toList();
    return RiderEarningsPeriodSnapshot(
      rangeTitle: rangeTitle,
      rangeSubtitle: rangeSubtitle,
      netTotal: net,
      tripCount: orders.length,
      lineItems: lines,
    );
  }
}
