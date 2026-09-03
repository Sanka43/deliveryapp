import 'package:intl/intl.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_period_keys.dart';
import 'package:mnd_rider/features/earnings/domain/rider_delivery_stats.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_analytics.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_chart_point.dart';
import 'package:mnd_rider/features/earnings/domain/rider_wallet.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';

/// Client-side revenue and job statistics from delivered orders and
/// completed passenger rides. Amounts here are gross (fee/fare, not
/// commission-adjusted) — they drive the day-by-day chart shape and the
/// stats grid, not the authoritative period totals (see
/// `RiderEarningsRepository.watchEarningsAggregate`, which is server-computed
/// and commission-adjusted).
abstract final class RiderEarningsAggregator {
  static DateTime orderCompletedAt(RiderOrderDetail order) =>
      order.deliveredAt ?? order.createdAt ?? DateTime.now();

  static DateTime tripCompletedAt(RiderPassengerTrip trip) =>
      trip.createdAt ?? DateTime.now();

  static RiderDeliveryStats deliveryStats(
    List<RiderOrderDetail> orders, [
    List<RiderPassengerTrip> trips = const <RiderPassengerTrip>[],
  ]) {
    if (orders.isEmpty && trips.isEmpty) {
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
    final int jobCount = orders.length + trips.length;

    void tally(DateTime at, double amount) {
      totalFees += amount;
      final String dayKey = DateFormat('yyyy-MM-dd').format(
        RiderEarningsPeriodKeys.startOfDay(at),
      );
      byDay[dayKey] = (byDay[dayKey] ?? 0) + amount;
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

    for (final RiderOrderDetail o in orders) {
      tally(orderCompletedAt(o), o.deliveryFeeLkr.toDouble());
    }
    for (final RiderPassengerTrip t in trips) {
      tally(tripCompletedAt(t), t.estimatedFareLkr.toDouble());
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
      totalDeliveries: jobCount,
      todayDeliveries: today,
      weekDeliveries: week,
      monthDeliveries: month,
      avgEarningPerTripLkr: jobCount == 0 ? 0 : totalFees / jobCount,
      bestDayEarningsLkr: bestAmount,
      bestDayLabel: bestLabel,
    );
  }

  static List<RiderEarningsChartPoint> last7DaysChart(
    List<RiderOrderDetail> orders, [
    List<RiderPassengerTrip> trips = const <RiderPassengerTrip>[],
  ]) {
    final DateTime today = RiderEarningsPeriodKeys.startOfDay(DateTime.now());
    final List<RiderEarningsChartPoint> points = <RiderEarningsChartPoint>[];

    for (int i = 6; i >= 0; i--) {
      final DateTime day = today.subtract(Duration(days: i));
      final DateTime next = day.add(const Duration(days: 1));
      double sum = 0;
      int jobs = 0;
      for (final RiderOrderDetail o in orders) {
        final DateTime at = orderCompletedAt(o);
        if (!at.isBefore(day) && at.isBefore(next)) {
          sum += o.deliveryFeeLkr;
          jobs++;
        }
      }
      for (final RiderPassengerTrip t in trips) {
        final DateTime at = tripCompletedAt(t);
        if (!at.isBefore(day) && at.isBefore(next)) {
          sum += t.estimatedFareLkr;
          jobs++;
        }
      }
      points.add(
        RiderEarningsChartPoint(
          label: DateFormat('EEE').format(day),
          earningsLkr: sum,
          tripCount: jobs,
          date: day,
        ),
      );
    }
    return points;
  }

  static double weekOverWeekGrowthPercent(
    List<RiderOrderDetail> orders, [
    List<RiderPassengerTrip> trips = const <RiderPassengerTrip>[],
  ]) {
    final DateTime now = DateTime.now();
    final DateTime thisWeekStart = RiderEarningsPeriodKeys.startOfWeek(now);
    final DateTime lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    double thisWeek = 0;
    double lastWeek = 0;

    void tally(DateTime at, double amount) {
      if (!at.isBefore(thisWeekStart)) {
        thisWeek += amount;
      } else if (!at.isBefore(lastWeekStart) && at.isBefore(thisWeekStart)) {
        lastWeek += amount;
      }
    }

    for (final RiderOrderDetail o in orders) {
      tally(orderCompletedAt(o), o.deliveryFeeLkr.toDouble());
    }
    for (final RiderPassengerTrip t in trips) {
      tally(tripCompletedAt(t), t.estimatedFareLkr.toDouble());
    }

    if (lastWeek <= 0) {
      return thisWeek > 0 ? 100 : 0;
    }
    return ((thisWeek - lastWeek) / lastWeek) * 100;
  }

  static RiderEarningsAnalytics buildAnalytics({
    required RiderWallet wallet,
    required List<RiderOrderDetail> orders,
    List<RiderPassengerTrip> trips = const <RiderPassengerTrip>[],
  }) {
    return RiderEarningsAnalytics(
      wallet: wallet,
      stats: deliveryStats(orders, trips),
      last7DaysChart: last7DaysChart(orders, trips),
      weekGrowthPercent: weekOverWeekGrowthPercent(orders, trips),
    );
  }
}
