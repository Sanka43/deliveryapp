import 'package:cloud_firestore/cloud_firestore.dart';

/// `riders/{riderId}/earnings_aggregates/{periodKey}`
/// periodKey examples: `daily_2026-05-17`, `weekly_2026-W20`, `monthly_2026-05`
enum RiderEarningsPeriodType {
  daily,
  weekly,
  monthly,
}

class RiderEarningsAggregate {
  const RiderEarningsAggregate({
    required this.periodKey,
    required this.periodType,
    required this.totalLkr,
    required this.tripCount,
    this.updatedAt,
  });

  final String periodKey;
  final RiderEarningsPeriodType periodType;
  final double totalLkr;
  final int tripCount;
  final DateTime? updatedAt;

  factory RiderEarningsAggregate.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    return RiderEarningsAggregate(
      periodKey: id,
      periodType: _parseType(data['periodType'] as String?),
      totalLkr: _readDouble(data['totalLkr']),
      tripCount: _readInt(data['tripCount']),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  static RiderEarningsPeriodType _parseType(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'weekly':
        return RiderEarningsPeriodType.weekly;
      case 'monthly':
        return RiderEarningsPeriodType.monthly;
      default:
        return RiderEarningsPeriodType.daily;
    }
  }

  static double _readDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
