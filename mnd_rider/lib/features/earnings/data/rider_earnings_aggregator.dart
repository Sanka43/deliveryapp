import 'package:intl/intl.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_period_keys.dart';
import 'package:mnd_rider/features/earnings/domain/rider_delivery_stats.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_analytics.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_chart_point.dart';
import 'package:mnd_rider/features/earnings/domain/rider_wallet.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

/// Client-side revenue and delivery statistics from delivered orders.
abstract final class RiderEarningsAggregator {
  static DateTime orderCompletedAt(RiderOrderDetail order) =>
      order.deliveredAt ?? order.createdAt ?? DateTime.now();

  static RiderDeliveryStats deliveryStats(List<RiderOrderDetail> orders) {
    if (orders.isEmpty) {
      return const RiderDeliveryStats.empty();
    }

    final DateTime now = DateTime.now();
    final DateTime startOfDay = RiderEarningsPeriodKeys.startOfDay(now);
    final DateTime startOfWeek = RiderEarningsPeriodKeys.startOfWeek(now);
    final DateTime startOfMonth = RiderEarningsPeriodKeys.startOfMonth(now);

    int today = 0;
    int week = 0;
    int month = 0;
    double totalFees = 0;
    final Map<String, double> byDay = <String, double>{};

    for (final RiderOrderDetail o in orders) {
      final DateTime at = orderCompletedAt(o);
      final double fee = o.deliveryFeeLkr.toDouble();
      totalFees += fee;

      final String dayKey = DateFormat('yyyy-MM-dd').format(
        RiderEarningsPeriodKeys.startOfDay(at),
      );
      byDay[dayKey] = (byDay[dayKey] ?? 0) + fee;

      if (!at.isBefore(startOfDay)) {
        today++;
      }
      if (!at.isBefore(startOfWeek)) {
        week++;
      }
      if (!at.isBefore(startOfMonth)) {
        month++;
      }
    }

    String bestLabel = '—';
    double bestAmount = 0;
    byDay.forEach((String key, double amount) {
      if (amount > bestAmount) {
        bestAmount = amount;
        final DateTime d = DateTime.parse(key);
        bestLabel = DateFormat('EEE d MMM').format(d);
      }
    });

    return RiderDeliveryStats(
      totalDeliveries: orders.length,
      todayDeliveries: today,
      weekDeliveries: week,
      monthDeliveries: month,
      avgEarningPerTripLkr: orders.isEmpty ? 0 : totalFees / orders.length,
      bestDayEarningsLkr: bestAmount,
      bestDayLabel: bestLabel,
    );
  }

  static List<RiderEarningsChartPoint> last7DaysChart(
    List<RiderOrderDetail> orders,
  ) {
    final DateTime today = RiderEarningsPeriodKeys.startOfDay(DateTime.now());
    final List<RiderEarningsChartPoint> points = <RiderEarningsChartPoint>[];

    for (int i = 6; i >= 0; i--) {
      final DateTime day = today.subtract(Duration(days: i));
      final DateTime next = day.add(const Duration(days: 1));
      double sum = 0;
      int trips = 0;
      for (final RiderOrderDetail o in orders) {
        final DateTime at = orderCompletedAt(o);
        if (!at.isBefore(day) && at.isBefore(next)) {
          sum += o.deliveryFeeLkr;
          trips++;
        }
      }
      points.add(
        RiderEarningsChartPoint(
          label: DateFormat('EEE').format(day),
          earningsLkr: sum,
          tripCount: trips,
          date: day,
        ),
      );
    }
    return points;
  }

  static double weekOverWeekGrowthPercent(List<RiderOrderDetail> orders) {
    final DateTime now = DateTime.now();
    final DateTime thisWeekStart = RiderEarningsPeriodKeys.startOfWeek(now);
    final DateTime lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    double thisWeek = 0;
    double lastWeek = 0;

    for (final RiderOrderDetail o in orders) {
      final DateTime at = orderCompletedAt(o);
      final double fee = o.deliveryFeeLkr.toDouble();
      if (!at.isBefore(thisWeekStart)) {
        thisWeek += fee;
      } else if (!at.isBefore(lastWeekStart) && at.isBefore(thisWeekStart)) {
        lastWeek += fee;
      }
    }

    if (lastWeek <= 0) {
      return thisWeek > 0 ? 100 : 0;
    }
    return ((thisWeek - lastWeek) / lastWeek) * 100;
  }

  static RiderEarningsAnalytics buildAnalytics({
    required RiderWallet wallet,
    required List<RiderOrderDetail> orders,
  }) {
    return RiderEarningsAnalytics(
      wallet: wallet,
      stats: deliveryStats(orders),
      last7DaysChart: last7DaysChart(orders),
      weekGrowthPercent: weekOverWeekGrowthPercent(orders),
    );
  }
}
