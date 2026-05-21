import 'package:mnd_rider/features/earnings/domain/rider_earnings_line_item.dart';

/// One tab: total net, trip count, and optional activity rows.
class RiderEarningsPeriodSnapshot {
  const RiderEarningsPeriodSnapshot({
    required this.rangeTitle,
    required this.rangeSubtitle,
    required this.netTotal,
    required this.tripCount,
    required this.lineItems,
  });

  final String rangeTitle;
  final String rangeSubtitle;
  final double netTotal;
  final int tripCount;
  final List<RiderEarningsLineItem> lineItems;
}
