/// One bar/point on the earnings trend chart.
class RiderEarningsChartPoint {
  const RiderEarningsChartPoint({
    required this.label,
    required this.earningsLkr,
    required this.tripCount,
    required this.date,
  });

  final String label;
  final double earningsLkr;
  final int tripCount;
  final DateTime date;
}
