/// Aggregated sales for the vendor dashboard (demo until backend / Firestore).
class VendorSalesSummary {
  const VendorSalesSummary({
    required this.todayGross,
    required this.weekGross,
    required this.priorWeekGross,
    required this.monthGross,
    required this.ordersToday,
    required this.ordersWeek,
    required this.ordersMonth,
    required this.completionRatePercent,
    required this.weekOverWeekGrowthPercent,
  });

  final double todayGross;
  final double weekGross;
  /// Completed-order gross for the 7 days before the current week window.
  final double priorWeekGross;
  final double monthGross;
  final int ordersToday;
  final int ordersWeek;
  final int ordersMonth;
  /// 0–100, derived from today's completed vs cancelled terminal orders.
  final double completionRatePercent;
  /// Positive = growth vs prior week.
  final double weekOverWeekGrowthPercent;

  static const VendorSalesSummary zero = VendorSalesSummary(
    todayGross: 0,
    weekGross: 0,
    priorWeekGross: 0,
    monthGross: 0,
    ordersToday: 0,
    ordersWeek: 0,
    ordersMonth: 0,
    completionRatePercent: 100,
    weekOverWeekGrowthPercent: 0,
  );
}
