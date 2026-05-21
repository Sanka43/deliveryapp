import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_sales_summary.dart';

/// Derives dashboard sales KPIs from recent order documents (same snapshot as the order board).
abstract final class VendorSalesAggregator {
  static VendorSalesSummary fromOrders(
    Iterable<VendorPendingOrder> orders, {
    required DateTime now,
  }) {
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);
    final DateTime weekStart = startOfToday.subtract(const Duration(days: 6));
    final DateTime priorWeekStart = weekStart.subtract(const Duration(days: 7));
    final DateTime monthStart = DateTime(now.year, now.month, 1);

    double todayGross = 0;
    int ordersToday = 0;
    double weekGross = 0;
    int ordersWeek = 0;
    double monthGross = 0;
    int ordersMonth = 0;
    double priorWeekGross = 0;
    int completedToday = 0;
    int cancelledToday = 0;

    for (final VendorPendingOrder o in orders) {
      final DateTime? at = o.createdAt;
      if (at == null) {
        continue;
      }
      final String status = o.statusKey;
      final bool isCompleted = status == 'completed';
      final bool isCancelled = status == 'cancelled';

      if (isCompleted) {
        if (!_isBeforeDay(at, startOfToday)) {
          todayGross += o.total;
          ordersToday++;
        }
        if (!_isBeforeDay(at, weekStart)) {
          weekGross += o.total;
          ordersWeek++;
        }
        if (!_isBeforeDay(at, monthStart)) {
          monthGross += o.total;
          ordersMonth++;
        }
        if (_isBeforeDay(at, weekStart) && !_isBeforeDay(at, priorWeekStart)) {
          priorWeekGross += o.total;
        }
      }

      if (!_isBeforeDay(at, startOfToday)) {
        if (isCompleted) {
          completedToday++;
        } else if (isCancelled) {
          cancelledToday++;
        }
      }
    }

    final int terminalToday = completedToday + cancelledToday;
    final double completionRatePercent = terminalToday > 0
        ? (completedToday / terminalToday) * 100
        : 100;

    final double weekOverWeekGrowthPercent = priorWeekGross > 0
        ? ((weekGross - priorWeekGross) / priorWeekGross) * 100
        : (weekGross > 0 ? 100 : 0);

    return VendorSalesSummary(
      todayGross: todayGross,
      weekGross: weekGross,
      monthGross: monthGross,
      ordersToday: ordersToday,
      ordersWeek: ordersWeek,
      ordersMonth: ordersMonth,
      completionRatePercent: completionRatePercent,
      weekOverWeekGrowthPercent: weekOverWeekGrowthPercent,
    );
  }

  static bool _isBeforeDay(DateTime a, DateTime startOfDay) =>
      a.isBefore(startOfDay);
}
