import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_catalog_metrics_snapshot.dart';
import 'package:mnd_shop/features/dashboard/presentation/providers/vendor_catalog_metrics_provider.dart';
import 'package:mnd_shop/features/dashboard/presentation/widgets/vendor_dashboard_ui.dart';
import 'package:mnd_shop/features/dashboard/presentation/widgets/vendor_pill_bottom_nav.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/orders/presentation/providers/vendor_order_board_provider.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_products_stream_provider.dart';
import 'package:mnd_shop/features/reports/data/vendor_stats_repository.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_snapshot.dart';
import 'package:mnd_shop/features/reports/presentation/pages/vendor_reports_page.dart';
import 'package:mnd_shop/features/reports/presentation/providers/vendor_reports_provider.dart';
import 'package:mnd_shop/features/reports/presentation/widgets/vendor_analytics_widgets.dart';

class VendorAnalyticsTabPage extends ConsumerWidget {
  const VendorAnalyticsTabPage({super.key});

  static const int _lowStockMax = 9;

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final VendorAnalyticsRange current = ref.read(vendorAnalyticsRangeProvider);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: current.start.toLocal(),
        end: current.end.toLocal(),
      ),
    );
    if (picked == null) {
      return;
    }
    ref.read(vendorAnalyticsRangeProvider.notifier).state = current.custom(
      picked.start,
      picked.end,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VendorAnalyticsRange range = ref.watch(vendorAnalyticsRangeProvider);
    final AsyncValue<VendorReportSnapshot> asyncData = ref.watch(
      vendorStatsReportsProvider,
    );
    final VendorReportSnapshot data = ref.watch(vendorReportsProvider);
    final VendorOrderBoard board =
        ref.watch(vendorOrderBoardProvider).valueOrNull ??
        VendorOrderBoard.empty;
    final VendorCatalogMetricsSnapshot catalogMetrics = ref.watch(
      vendorCatalogMetricsProvider,
    );
    final List<VendorProduct> products =
        ref.watch(vendorProductsStreamProvider).valueOrNull ??
        const <VendorProduct>[];
    final List<VendorProduct> stockWatch = _stockWatchProducts(products);
    final List<DailySalesPoint> days = data.last7Days;
    final double maxGross = math.max(
      1,
      days.isEmpty
          ? 1
          : days.map((DailySalesPoint e) => e.grossLkr).reduce(math.max) * 1.12,
    );
    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), days[i].grossLkr),
    ];
    final ProductSalesPoint? best = data.bestSellingProduct;
    final List<ProductSalesPoint> productRowsByQuantity =
        data.productRows.toList(growable: false)
          ..sort((ProductSalesPoint a, ProductSalesPoint b) {
            final int quantity = b.quantity.compareTo(a.quantity);
            if (quantity != 0) {
              return quantity;
            }
            return b.grossLkr.compareTo(a.grossLkr);
          });
    final List<String> insights = _buildInsights(
      data: data,
      best: best,
      board: board,
      catalog: catalogMetrics,
    );
    final double gutter = vendorResponsiveHorizontalPadding(context);
    final bool tablet = vendorUsesTabletLayout(context);

    return Scaffold(
      backgroundColor: VendorDashboardTheme.canvas(context),
      body: VendorResponsiveContent(
        child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vendorStatsReportsProvider);
          ref.invalidate(vendorOrderBoardProvider);
          await Future<void>.delayed(const Duration(milliseconds: 350));
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                MediaQuery.paddingOf(context).top + 12,
                gutter,
                8,
              ),
              sliver: SliverToBoxAdapter(
                child: VendorPageHeader(
                  title: _vTxt(context, en: 'Analytics', si: 'විශ්ලේෂණ'),
                  titleColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onSurface
                      : null,
                  trailing: IconButton.filledTonal(
                    tooltip: _vTxt(context, en: 'Reports', si: 'වාර්තා'),
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext ctx) =>
                              const VendorReportsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_rounded),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 14),
              sliver: SliverToBoxAdapter(
                child: VendorAnalyticsRangeSelector(
                  selected: range.preset,
                  onPreset: (VendorAnalyticsPreset preset) {
                    ref.read(vendorAnalyticsRangeProvider.notifier).state =
                        VendorAnalyticsRange.forPreset(preset);
                  },
                  onCustom: () => _pickCustomRange(context, ref),
                ),
              ),
            ),
            if (asyncData.isLoading)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
              sliver: SliverToBoxAdapter(
                child: VendorAnalyticsSalesTrendHero(
                  days: days,
                  spots: spots,
                  maxGross: maxGross,
                  totalSales: data.grossLkr,
                  best: best,
                  compactLkr: vendorAnalyticsFormatLkr,
                  formatMoney: vendorAnalyticsFormatMoney,
                  title: 'Sales trend',
                  chartHeight: 168,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
              sliver: SliverGrid.count(
                crossAxisCount: tablet ? 4 : 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: tablet ? 2.2 : 2.55,
                children: <Widget>[
                  VendorAnalyticsMetricTile(
                    label: 'Total sales',
                    value: vendorAnalyticsFormatMoney(data.grossLkr),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.vendorHeroBlue,
                  ),
                  VendorAnalyticsMetricTile(
                    label: 'Orders',
                    value: '${data.completedOrders}',
                    icon: Icons.shopping_bag_rounded,
                    color: AppColors.vendorHeroBlue,
                  ),
                  VendorAnalyticsMetricTile(
                    label: 'Average order',
                    value: vendorAnalyticsFormatMoney(data.averageOrderValueLkr),
                    icon: Icons.show_chart_rounded,
                    color: AppColors.vendorHeroBlue,
                  ),
                  VendorAnalyticsMetricTile(
                    label: 'Cancelled',
                    value:
                        '${data.cancelledOrders} · ${data.cancellationRatePercent.toStringAsFixed(1)}%',
                    icon: Icons.highlight_off_rounded,
                    color: AppColors.vendorHeroBlue,
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
              sliver: SliverToBoxAdapter(
                child: VendorAnalyticsInventoryHealthPanel(
                  metrics: catalogMetrics,
                  products: stockWatch,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
              sliver: SliverToBoxAdapter(
                child: VendorAnalyticsInsightsPanel(insights: insights),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                0,
                gutter,
                VendorPillBottomNav.scrollBottomPadding(context, extra: 0),
              ),
              sliver: SliverToBoxAdapter(
                child: _ProductWiseSellingPanel(
                  rows: productRowsByQuantity.take(5).toList(growable: false),
                  totalGross: data.grossLkr,
                  hasMore: productRowsByQuantity.length > 5,
                  onSeeAll: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext ctx) =>
                            const VendorReportsPage(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  static List<VendorProduct> _stockWatchProducts(List<VendorProduct> products) {
    final List<VendorProduct> rows = products
        .where(
          (VendorProduct p) =>
              !p.active ||
              (p.manageStock && p.stockQty <= _lowStockMax),
        )
        .toList(growable: false);
    rows.sort((VendorProduct a, VendorProduct b) {
      final bool aOut = a.manageStock && a.stockQty == 0;
      final bool bOut = b.manageStock && b.stockQty == 0;
      if (aOut && !bOut) {
        return -1;
      }
      if (!aOut && bOut) {
        return 1;
      }
      if (a.active != b.active) {
        return a.active ? 1 : -1;
      }
      if (!a.manageStock && b.manageStock) {
        return 1;
      }
      if (a.manageStock && !b.manageStock) {
        return -1;
      }
      return a.stockQty.compareTo(b.stockQty);
    });
    return rows.take(5).toList(growable: false);
  }

  static List<String> _buildInsights({
    required VendorReportSnapshot data,
    required ProductSalesPoint? best,
    required VendorOrderBoard board,
    required VendorCatalogMetricsSnapshot catalog,
  }) {
    final List<String> out = <String>[];
    if (best != null) {
      out.add(
        '${best.productName} is leading this range with ${best.quantity} sold.',
      );
    }
    if (catalog.outCount > 0 || catalog.lowCount > 0) {
      out.add(
        '${catalog.outCount} out of stock and ${catalog.lowCount} low stock products need attention.',
      );
    }
    if (board.activeCount > 0) {
      out.add(
        '${board.activeCount} active orders are moving through the shop now.',
      );
    }
    if (data.cancellationRatePercent >= 15 && data.cancelledOrders >= 2) {
      out.add(
        'Cancellation rate is ${data.cancellationRatePercent.toStringAsFixed(1)}%; check rejected or delayed orders.',
      );
    }
    if (data.completedOrders > 0) {
      out.add(
        'Average order value is ${vendorAnalyticsFormatMoney(data.averageOrderValueLkr)} for this range.',
      );
    }
    if (out.isEmpty) {
      out.add(
        'Start completing orders and this page will show useful shop insights.',
      );
    }
    return out.take(4).toList(growable: false);
  }
}


class _ProductWiseSellingPanel extends StatelessWidget {
  const _ProductWiseSellingPanel({
    required this.rows,
    required this.totalGross,
    required this.hasMore,
    required this.onSeeAll,
  });

  final List<ProductSalesPoint> rows;
  final double totalGross;
  final bool hasMore;
  final VoidCallback onSeeAll;

  static const Color _accent = AppColors.vendorHeroBlue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Product-wise selling',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Top products by quantity sold',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: VendorDashboardTheme.mutedText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (rows.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Top ${rows.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        color: _accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No product sales yet',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: VendorDashboardTheme.mutedText(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...<Widget>[
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              _ProductSalesRow(
                row: rows[i],
                total: totalGross,
                index: i,
              ),
            ],
            if (hasMore) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSeeAll,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('See all products'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: BorderSide(color: _accent.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ProductSalesRow extends StatelessWidget {
  const _ProductSalesRow({
    required this.row,
    required this.total,
    required this.index,
  });

  final ProductSalesPoint row;
  final double total;
  final int index;

  static const Color _accent = AppColors.vendorHeroBlue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double pct = total <= 0 ? 0 : (row.grossLkr / total).clamp(0.0, 1.0);
    final double pctLabel = pct * 100;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.itemsBoxFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index == 0 ? _accent : _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${index + 1}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: index == 0 ? Colors.white : _accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: _accent.withValues(alpha: 0.1),
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${row.quantity} sold · ${pctLabel.toStringAsFixed(1)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: VendorDashboardTheme.mutedText(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            vendorAnalyticsFormatMoney(row.grossLkr),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: _accent,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

String _vTxt(
  BuildContext context, {
  required String en,
  required String si,
  String? ta,
}) {
  final String languageCode = Localizations.localeOf(context).languageCode;
  if (languageCode == 'si') return si;
  if (languageCode == 'ta') return ta ?? vendorTamilFallback(en);
  return en;
}
