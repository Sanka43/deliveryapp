/// Aggregated sales for the vendor dashboard (demo until backend / Firestore).
class VendorSalesSummary {
  const VendorSalesSummary({
    required this.todayGross,
    required this.weekGross,
    required this.monthGross,
    required this.ordersToday,
    required this.ordersWeek,
    required this.ordersMonth,
    required this.completionRatePercent,
    required this.weekOverWeekGrowthPercent,
  });

  final double todayGross;
  final double weekGross;
  final double monthGross;
  final int ordersToday;
  final int ordersWeek;
  final int ordersMonth;
  /// 0–100, demo until derived from order outcomes.
  final double completionRatePercent;
  /// Positive = growth vs prior week (demo aggregate).
  final double weekOverWeekGrowthPercent;

  static const VendorSalesSummary zero = VendorSalesSummary(
    todayGross: 0,
    weekGross: 0,
    monthGross: 0,
    ordersToday: 0,
    ordersWeek: 0,
    ordersMonth: 0,
    completionRatePercent: 100,
    weekOverWeekGrowthPercent: 0,
  );
}
