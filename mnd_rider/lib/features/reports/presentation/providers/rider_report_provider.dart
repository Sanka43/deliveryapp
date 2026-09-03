import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/reports/data/rider_report_repository.dart';
import 'package:mnd_rider/features/reports/domain/rider_report_data.dart';

/// Quick presets for the report range picker.
enum RiderReportPreset { today, thisWeek, thisMonth, custom }

class RiderReportRange {
  const RiderReportRange({
    required this.preset,
    required this.start,
    required this.end,
  });

  final RiderReportPreset preset;
  final DateTime start;
  final DateTime end;

  static RiderReportRange forPreset(RiderReportPreset preset) {
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime todayEnd = todayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    switch (preset) {
      case RiderReportPreset.today:
        return RiderReportRange(
          preset: preset,
          start: todayStart,
          end: todayEnd,
        );
      case RiderReportPreset.thisWeek:
        final DateTime weekStart = todayStart.subtract(
          Duration(days: now.weekday - DateTime.monday),
        );
        return RiderReportRange(
          preset: preset,
          start: weekStart,
          end: todayEnd,
        );
      case RiderReportPreset.thisMonth:
        final DateTime monthStart = DateTime(now.year, now.month);
        return RiderReportRange(
          preset: preset,
          start: monthStart,
          end: todayEnd,
        );
      case RiderReportPreset.custom:
        return RiderReportRange(
          preset: preset,
          start: todayStart,
          end: todayEnd,
        );
    }
  }
}

final StateProvider<RiderReportRange> riderReportRangeProvider =
    StateProvider<RiderReportRange>(
  (Ref ref) => RiderReportRange.forPreset(RiderReportPreset.today),
);

final FutureProviderFamily<RiderReportData, RiderReportRange>
    riderReportDataProvider =
    FutureProvider.family<RiderReportData, RiderReportRange>(
  (Ref ref, RiderReportRange range) {
    return ref
        .watch(riderReportRepositoryProvider)
        .fetchReport(start: range.start, end: range.end);
  },
);
