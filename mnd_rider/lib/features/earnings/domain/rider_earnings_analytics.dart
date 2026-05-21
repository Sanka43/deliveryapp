import 'package:mnd_rider/features/earnings/domain/rider_delivery_stats.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_chart_point.dart';
import 'package:mnd_rider/features/earnings/domain/rider_wallet.dart';

/// Combined analytics view for the earnings hub screen.
class RiderEarningsAnalytics {
  const RiderEarningsAnalytics({
    required this.wallet,
    required this.stats,
    required this.last7DaysChart,
    required this.weekGrowthPercent,
  });

  final RiderWallet wallet;
  final RiderDeliveryStats stats;
  final List<RiderEarningsChartPoint> last7DaysChart;
  final double weekGrowthPercent;
}
