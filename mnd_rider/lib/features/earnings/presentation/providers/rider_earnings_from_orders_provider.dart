import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_aggregator.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_repository.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_snapshots.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_analytics.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_period_snapshot.dart';
import 'package:mnd_rider/features/earnings/domain/rider_transaction.dart';
import 'package:mnd_rider/features/earnings/domain/rider_wallet.dart';
import 'package:mnd_rider/features/earnings/domain/rider_withdrawal.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

final Provider<RiderEarningsSummary> riderEarningsSummaryProvider =
    Provider<RiderEarningsSummary>((Ref ref) {
  final AsyncValue<List<RiderOrderDetail>> history =
      ref.watch(riderDeliveredHistoryProvider);
  return history.when(
    data: _summaryFromOrders,
    loading: () => const RiderEarningsSummary.empty(),
    error: (_, __) => const RiderEarningsSummary.empty(),
  );
});

final Provider<RiderEarningsPeriodSnapshot> riderDailyEarningsSnapshotProvider =
    Provider<RiderEarningsPeriodSnapshot>((Ref ref) {
  final List<RiderOrderDetail> orders =
      ref.watch(riderDeliveredHistoryProvider).valueOrNull ??
          const <RiderOrderDetail>[];
  return RiderEarningsSnapshots.dailyFromOrders(orders);
});

final Provider<RiderEarningsPeriodSnapshot> riderWeeklyEarningsSnapshotProvider =
    Provider<RiderEarningsPeriodSnapshot>((Ref ref) {
  final List<RiderOrderDetail> orders =
      ref.watch(riderDeliveredHistoryProvider).valueOrNull ??
          const <RiderOrderDetail>[];
  return RiderEarningsSnapshots.weeklyFromOrders(orders);
});

final Provider<RiderEarningsPeriodSnapshot> riderMonthlyEarningsSnapshotProvider =
    Provider<RiderEarningsPeriodSnapshot>((Ref ref) {
  final List<RiderOrderDetail> orders =
      ref.watch(riderDeliveredHistoryProvider).valueOrNull ??
          const <RiderOrderDetail>[];
  return RiderEarningsSnapshots.monthlyFromOrders(orders);
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
  final RiderWallet wallet =
      ref.watch(riderWalletProvider).valueOrNull ?? const RiderWallet.empty();
  return RiderEarningsAggregator.buildAnalytics(
    wallet: wallet,
    orders: orders,
  );
});

RiderEarningsSummary _summaryFromOrders(List<RiderOrderDetail> orders) {
  final stats = RiderEarningsAggregator.deliveryStats(orders);
  double todayNet = 0;
  double weekNet = 0;
  double monthNet = 0;

  final DateTime now = DateTime.now();
  final DateTime dayStart = DateTime(now.year, now.month, now.day);
  final DateTime weekStart =
      dayStart.subtract(Duration(days: now.weekday - DateTime.monday));
  final DateTime monthStart = DateTime(now.year, now.month);

  for (final RiderOrderDetail o in orders) {
    final DateTime at = RiderEarningsAggregator.orderCompletedAt(o);
    final double fee = o.deliveryFeeLkr.toDouble();
    if (!at.isBefore(dayStart)) {
      todayNet += fee;
    }
    if (!at.isBefore(weekStart)) {
      weekNet += fee;
    }
    if (!at.isBefore(monthStart)) {
      monthNet += fee;
    }
  }

  return RiderEarningsSummary(
    todayNet: todayNet,
    weekNet: weekNet,
    monthNet: monthNet,
    tripsToday: stats.todayDeliveries,
    tripsWeek: stats.weekDeliveries,
    tripsMonth: stats.monthDeliveries,
  );
}
