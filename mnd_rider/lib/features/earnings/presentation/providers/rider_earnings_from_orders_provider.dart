import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_aggregator.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_period_keys.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_repository.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_snapshots.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_aggregate.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_analytics.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_period_snapshot.dart';
import 'package:mnd_rider/features/earnings/domain/rider_transaction.dart';
import 'package:mnd_rider/features/earnings/domain/rider_wallet.dart';
import 'package:mnd_rider/features/earnings/domain/rider_withdrawal.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';

/// The rider's own completed passenger rides, as watched by the earnings hub
/// (separate provider name from [riderCompletedTripsProvider] so the
/// history screen's "Load more" page size never affects earnings totals —
/// same reasoning as [riderDeliveredHistoryProvider]).
final StreamProvider<List<RiderPassengerTrip>> riderEarningsCompletedTripsProvider =
    StreamProvider<List<RiderPassengerTrip>>((Ref ref) {
  return ref.watch(riderTripsRepositoryProvider).watchMyCompletedTrips(limit: 200);
});

final StreamProvider<RiderEarningsAggregate?> riderDailyEarningsAggregateProvider =
    StreamProvider<RiderEarningsAggregate?>((Ref ref) {
  final String key = RiderEarningsPeriodKeys.dailyKey(DateTime.now());
  return ref.watch(riderEarningsRepositoryProvider).watchEarningsAggregate(key);
});

final StreamProvider<RiderEarningsAggregate?> riderWeeklyEarningsAggregateProvider =
    StreamProvider<RiderEarningsAggregate?>((Ref ref) {
  final String key = RiderEarningsPeriodKeys.weeklyKey(DateTime.now());
  return ref.watch(riderEarningsRepositoryProvider).watchEarningsAggregate(key);
});

final StreamProvider<RiderEarningsAggregate?> riderMonthlyEarningsAggregateProvider =
    StreamProvider<RiderEarningsAggregate?>((Ref ref) {
  final String key = RiderEarningsPeriodKeys.monthlyKey(DateTime.now());
  return ref.watch(riderEarningsRepositoryProvider).watchEarningsAggregate(key);
});

final Provider<RiderEarningsSummary> riderEarningsSummaryProvider =
    Provider<RiderEarningsSummary>((Ref ref) {
  final List<RiderOrderDetail> orders =
      ref.watch(riderDeliveredHistoryProvider).valueOrNull ??
          const <RiderOrderDetail>[];
  final List<RiderPassengerTrip> trips =
      ref.watch(riderEarningsCompletedTripsProvider).valueOrNull ??
          const <RiderPassengerTrip>[];
  final RiderEarningsAggregate? daily =
      ref.watch(riderDailyEarningsAggregateProvider).valueOrNull;
  final RiderEarningsAggregate? weekly =
      ref.watch(riderWeeklyEarningsAggregateProvider).valueOrNull;
  final RiderEarningsAggregate? monthly =
      ref.watch(riderMonthlyEarningsAggregateProvider).valueOrNull;
  return _summaryFrom(orders, trips, daily, weekly, monthly);
});

final Provider<RiderEarningsPeriodSnapshot> riderDailyEarningsSnapshotProvider =
    Provider<RiderEarningsPeriodSnapshot>((Ref ref) {
  final List<RiderOrderDetail> orders =
      ref.watch(riderDeliveredHistoryProvider).valueOrNull ??
          const <RiderOrderDetail>[];
  final List<RiderPassengerTrip> trips =
      ref.watch(riderEarningsCompletedTripsProvider).valueOrNull ??
          const <RiderPassengerTrip>[];
  final RiderEarningsAggregate? aggregate =
      ref.watch(riderDailyEarningsAggregateProvider).valueOrNull;
  return RiderEarningsSnapshots.daily(
    orders: orders,
    trips: trips,
    aggregate: aggregate,
  );
});

final Provider<RiderEarningsPeriodSnapshot> riderWeeklyEarningsSnapshotProvider =
    Provider<RiderEarningsPeriodSnapshot>((Ref ref) {
  final List<RiderOrderDetail> orders =
      ref.watch(riderDeliveredHistoryProvider).valueOrNull ??
          const <RiderOrderDetail>[];
  final List<RiderPassengerTrip> trips =
      ref.watch(riderEarningsCompletedTripsProvider).valueOrNull ??
          const <RiderPassengerTrip>[];
  final RiderEarningsAggregate? aggregate =
      ref.watch(riderWeeklyEarningsAggregateProvider).valueOrNull;
  return RiderEarningsSnapshots.weekly(
    orders: orders,
    trips: trips,
    aggregate: aggregate,
  );
});

final Provider<RiderEarningsPeriodSnapshot> riderMonthlyEarningsSnapshotProvider =
    Provider<RiderEarningsPeriodSnapshot>((Ref ref) {
  final List<RiderOrderDetail> orders =
      ref.watch(riderDeliveredHistoryProvider).valueOrNull ??
          const <RiderOrderDetail>[];
  final List<RiderPassengerTrip> trips =
      ref.watch(riderEarningsCompletedTripsProvider).valueOrNull ??
          const <RiderPassengerTrip>[];
  final RiderEarningsAggregate? aggregate =
      ref.watch(riderMonthlyEarningsAggregateProvider).valueOrNull;
  return RiderEarningsSnapshots.monthly(
    orders: orders,
    trips: trips,
    aggregate: aggregate,
  );
});

final StreamProvider<RiderWallet> riderWalletProvider =
    StreamProvider<RiderWallet>((Ref ref) {
  return ref.watch(riderEarningsRepositoryProvider).watchWallet();
});

final StreamProvider<List<RiderTransaction>> riderTransactionsProvider =
    StreamProvider<List<RiderTransaction>>((Ref ref) {
  return ref.watch(riderEarningsRepositoryProvider).watchTransactions();
});

final StreamProvider<List<RiderWithdrawal>> riderWithdrawalsProvider =
    StreamProvider<List<RiderWithdrawal>>((Ref ref) {
  return ref.watch(riderEarningsRepositoryProvider).watchWithdrawals();
});

final Provider<RiderEarningsAnalytics> riderEarningsAnalyticsProvider =
    Provider<RiderEarningsAnalytics>((Ref ref) {
  final List<RiderOrderDetail> orders =
      ref.watch(riderDeliveredHistoryProvider).valueOrNull ??
          const <RiderOrderDetail>[];
  final List<RiderPassengerTrip> trips =
      ref.watch(riderEarningsCompletedTripsProvider).valueOrNull ??
          const <RiderPassengerTrip>[];
  final RiderWallet wallet =
      ref.watch(riderWalletProvider).valueOrNull ?? const RiderWallet.empty();
  return RiderEarningsAggregator.buildAnalytics(
    wallet: wallet,
    orders: orders,
    trips: trips,
  );
});

RiderEarningsSummary _summaryFrom(
  List<RiderOrderDetail> orders,
  List<RiderPassengerTrip> trips,
  RiderEarningsAggregate? daily,
  RiderEarningsAggregate? weekly,
  RiderEarningsAggregate? monthly,
) {
  final stats = RiderEarningsAggregator.deliveryStats(orders, trips);

  final DateTime now = DateTime.now();
  final DateTime dayStart = DateTime(now.year, now.month, now.day);
  final DateTime weekStart =
      dayStart.subtract(Duration(days: now.weekday - DateTime.monday));
  final DateTime monthStart = DateTime(now.year, now.month);

  double todayFallback = 0;
  double weekFallback = 0;
  double monthFallback = 0;

  void tally(DateTime at, double amount) {
    if (!at.isBefore(dayStart)) {
      todayFallback += amount;
    }
    if (!at.isBefore(weekStart)) {
      weekFallback += amount;
    }
    if (!at.isBefore(monthStart)) {
      monthFallback += amount;
    }
  }

  for (final RiderOrderDetail o in orders) {
    tally(RiderEarningsAggregator.orderCompletedAt(o), o.deliveryFeeLkr.toDouble());
  }
  for (final RiderPassengerTrip t in trips) {
    tally(RiderEarningsAggregator.tripCompletedAt(t), t.estimatedFareLkr.toDouble());
  }

  return RiderEarningsSummary(
    todayNet: daily?.totalLkr ?? todayFallback,
    weekNet: weekly?.totalLkr ?? weekFallback,
    monthNet: monthly?.totalLkr ?? monthFallback,
    tripsToday: stats.todayDeliveries,
    tripsWeek: stats.weekDeliveries,
    tripsMonth: stats.monthDeliveries,
  );
}
