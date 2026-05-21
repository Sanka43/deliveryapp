/// Delivery performance metrics derived from completed orders.
class RiderDeliveryStats {
  const RiderDeliveryStats({
    required this.totalDeliveries,
    required this.todayDeliveries,
    required this.weekDeliveries,
    required this.monthDeliveries,
    required this.avgEarningPerTripLkr,
    required this.bestDayEarningsLkr,
    required this.bestDayLabel,
  });

  const RiderDeliveryStats.empty()
      : totalDeliveries = 0,
        todayDeliveries = 0,
        weekDeliveries = 0,
        monthDeliveries = 0,
        avgEarningPerTripLkr = 0,
        bestDayEarningsLkr = 0,
        bestDayLabel = '—';

  final int totalDeliveries;
  final int todayDeliveries;
  final int weekDeliveries;
  final int monthDeliveries;
  final double avgEarningPerTripLkr;
  final double bestDayEarningsLkr;
  final String bestDayLabel;
}
