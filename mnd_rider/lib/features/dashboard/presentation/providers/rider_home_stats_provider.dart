import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/earnings/presentation/providers/rider_earnings_from_orders_provider.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

/// Realtime home dashboard metrics.
class RiderHomeStats {
  const RiderHomeStats({
    required this.todayEarningsLkr,
    required this.activeOrderCount,
    required this.completedToday,
    required this.openJobsCount,
    required this.totalAssignedCount,
  });

  const RiderHomeStats.empty()
      : todayEarningsLkr = 0,
        activeOrderCount = 0,
        completedToday = 0,
        openJobsCount = 0,
        totalAssignedCount = 0;

  final double todayEarningsLkr;
  final int activeOrderCount;
  final int completedToday;
  final int openJobsCount;
  final int totalAssignedCount;
}

final Provider<RiderHomeStats> riderHomeStatsProvider = Provider<RiderHomeStats>((Ref ref) {
  final earnings = ref.watch(riderEarningsSummaryProvider);
  final List<RiderAssignedOrder> assigned =
      ref.watch(assignedRiderOrdersProvider).valueOrNull ??
          const <RiderAssignedOrder>[];
  final List<RiderOrderDetail> open = ref.watch(riderIsApprovedToDriveProvider)
      ? (ref.watch(openRiderJobsProvider).valueOrNull ??
          const <RiderOrderDetail>[])
      : const <RiderOrderDetail>[];

  int active = 0;
  for (final RiderAssignedOrder o in assigned) {
    if (_activeStatuses.contains(o.status)) {
      active++;
    }
  }

  return RiderHomeStats(
    todayEarningsLkr: earnings.todayNet,
    activeOrderCount: active,
    completedToday: earnings.tripsToday,
    openJobsCount: open.length,
    totalAssignedCount: assigned.length,
  );
});

const Set<String> _activeStatuses = <String>{
  'out_for_delivery',
  'picked_up',
  'on_the_way',
};
