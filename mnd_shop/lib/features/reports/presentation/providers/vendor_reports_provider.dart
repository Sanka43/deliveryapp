import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/orders/presentation/providers/vendor_order_board_provider.dart';
import 'package:mnd_shop/features/reports/data/vendor_stats_repository.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_aggregator.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_snapshot.dart';

final StateProvider<VendorAnalyticsRange> vendorAnalyticsRangeProvider =
    StateProvider<VendorAnalyticsRange>((Ref ref) {
      return VendorAnalyticsRange.forPreset(VendorAnalyticsPreset.week);
    });

final StreamProvider<VendorReportSnapshot> vendorStatsReportsProvider =
    StreamProvider<VendorReportSnapshot>((Ref ref) {
      final String vendorId = ref.watch(vendorEffectiveStoreIdProvider).trim();
      if (vendorId.isEmpty) {
        return Stream<VendorReportSnapshot>.value(VendorReportSnapshot.empty);
      }
      return ref
          .watch(vendorStatsRepositoryProvider)
          .watchAnalyticsSnapshot(
            VendorStatsRequest(
              vendorId: vendorId,
              range: ref.watch(vendorAnalyticsRangeProvider),
            ),
          );
    });

VendorReportSnapshot _emptyForRange(VendorAnalyticsRange range) {
  return VendorReportSnapshot(
    last7Days: VendorReportSnapshot.empty.last7Days,
    categoryLabels: VendorReportSnapshot.empty.categoryLabels,
    categoryValuesLkr: VendorReportSnapshot.empty.categoryValuesLkr,
    rangeLabel: range.label,
  );
}

/// Prefer server-maintained vendor stats, with live orders as a fallback while stats catch up.
final Provider<VendorReportSnapshot> vendorReportsProvider =
    Provider<VendorReportSnapshot>((Ref ref) {
      final VendorAnalyticsRange range = ref.watch(
        vendorAnalyticsRangeProvider,
      );
      final AsyncValue<VendorReportSnapshot> asyncStats = ref.watch(
        vendorStatsReportsProvider,
      );
      final board = ref.watch(vendorOrderBoardProvider).valueOrNull;

      // Today stays live from the order board (hourly).
      if (range.preset == VendorAnalyticsPreset.today && board != null) {
        return VendorReportAggregator.fromOrderBoard(board, range: range);
      }

      // Never use valueOrNull across range changes — it keeps the previous
      // range's AsyncData and flashes wrong totals (e.g. week → month).
      final VendorReportSnapshot? stats = asyncStats.asData?.value;
      final VendorReportSnapshot? matchedStats =
          (stats != null && stats.rangeLabel == range.label) ? stats : null;

      // While the selected range is still loading, show an empty shell for that
      // range. Do NOT fall back to the order board here — board totals (e.g.
      // Rs. 8900) then get replaced by Firestore (e.g. Rs. 2450) and look like
      // a reload bug.
      final bool waitingForRangeStats =
          matchedStats == null &&
          (asyncStats.isLoading ||
              asyncStats.isRefreshing ||
              stats == null ||
              stats.rangeLabel != range.label);
      if (waitingForRangeStats) {
        return _emptyForRange(range);
      }

      if (matchedStats != null && matchedStats.hasSalesData) {
        return matchedStats;
      }

      // Server answered for this range but has no sales yet — board fallback.
      if (board != null) {
        return VendorReportAggregator.fromOrderBoard(board, range: range);
      }
      return matchedStats ?? _emptyForRange(range);
    });
