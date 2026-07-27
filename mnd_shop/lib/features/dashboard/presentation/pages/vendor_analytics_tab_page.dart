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

class VendorAnalyticsTabPage extends ConsumerWidget {
  const VendorAnalyticsTabPage({super.key});

  static const int _lowStockMax = 9;

  static String _money(double v) => 'Rs. ${v.toStringAsFixed(2)}';

  static String _compactLkr(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

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
                child: _RangeSelector(
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
                child: _SalesTrendHero(
                  days: days,
                  spots: spots,
                  maxGross: maxGross,
                  totalSales: data.grossLkr,
                  best: best,
                  compactLkr: _compactLkr,
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
                  _MetricTile(
                    label: 'Total sales',
                    value: _money(data.grossLkr),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.vendorHeroBlue,
                  ),
                  _MetricTile(
                    label: 'Orders',
                    value: '${data.completedOrders}',
                    icon: Icons.shopping_bag_rounded,
                    color: AppColors.vendorHeroBlue,
                  ),
                  _MetricTile(
                    label: 'Average order',
                    value: _money(data.averageOrderValueLkr),
                    icon: Icons.show_chart_rounded,
                    color: AppColors.vendorHeroBlue,
                  ),
                  _MetricTile(
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
                child: _InventoryHealthPanel(
                  metrics: catalogMetrics,
                  products: stockWatch,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
              sliver: SliverToBoxAdapter(
                child: _InsightsPanel(insights: insights),
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
        .where((VendorProduct p) => p.stockQty <= _lowStockMax || !p.active)
        .toList(growable: false);
    rows.sort((VendorProduct a, VendorProduct b) {
      if (a.stockQty == 0 && b.stockQty != 0) {
        return -1;
      }
      if (a.stockQty != 0 && b.stockQty == 0) {
        return 1;
      }
      if (a.active != b.active) {
        return a.active ? 1 : -1;
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
        'Average order value is ${_money(data.averageOrderValueLkr)} for this range.',
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

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,
    required this.onPreset,
    required this.onCustom,
  });

  final VendorAnalyticsPreset selected;
  final ValueChanged<VendorAnalyticsPreset> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isCustom = selected == VendorAnalyticsPreset.custom;
    final List<(VendorAnalyticsPreset, String)> presets =
        <(VendorAnalyticsPreset, String)>[
          (VendorAnalyticsPreset.today, 'Day'),
          (VendorAnalyticsPreset.week, 'Week'),
          (VendorAnalyticsPreset.month, 'Month'),
          (VendorAnalyticsPreset.year, 'Year'),
        ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.itemsBoxFill(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
      ),
      child: Row(
        children: <Widget>[
          for (final (VendorAnalyticsPreset, String) item in presets)
            Expanded(
              child: _RangePill(
                label: item.$2,
                selected: !isCustom && selected == item.$1,
                onTap: () => onPreset(item.$1),
              ),
            ),
          Material(
            color: isCustom ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onCustom,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Icon(
                  Icons.date_range_rounded,
                  size: 18,
                  color: isCustom ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected
            ? VendorDashboardTheme.cardSurface(context)
            : Colors.transparent,
        elevation: selected ? 1.5 : 0,
        shadowColor: cs.shadow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SalesTrendHero extends StatelessWidget {
  const _SalesTrendHero({
    required this.days,
    required this.spots,
    required this.maxGross,
    required this.totalSales,
    required this.best,
    required this.compactLkr,
  });

  final List<DailySalesPoint> days;
  final List<FlSpot> spots;
  final double maxGross;
  final double totalSales;
  final ProductSalesPoint? best;
  final String Function(double) compactLkr;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const Color onBlue = Colors.white;
    final Color onBlueMuted = Colors.white.withValues(alpha: 0.7);

    final int peakIndex = _peakIndex(days);
    final List<FlSpot> solidSpots = peakIndex < 0
        ? spots
        : spots.sublist(0, peakIndex + 1);
    final List<FlSpot> dashedSpots = peakIndex < 0 || peakIndex >= spots.length - 1
        ? const <FlSpot>[]
        : spots.sublist(peakIndex);
    final FlSpot? peakSpot = peakIndex >= 0 && peakIndex < spots.length
        ? spots[peakIndex]
        : null;
    final DailySalesPoint? peakDay =
        peakIndex >= 0 && peakIndex < days.length ? days[peakIndex] : null;

    // Glow layers share the solid segment so the neon trail matches the reference.
    final List<LineChartBarData> glowBars = <LineChartBarData>[
      _glowBar(
        spots: solidSpots,
        color: const Color(0xFF7EB6FF).withValues(alpha: 0.22),
        width: 14,
      ),
      _glowBar(
        spots: solidSpots,
        color: Colors.white.withValues(alpha: 0.28),
        width: 7,
      ),
      LineChartBarData(
        spots: solidSpots,
        isCurved: true,
        curveSmoothness: 0.38,
        color: onBlue,
        barWidth: 2.6,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          checkToShowDot: (FlSpot spot, LineChartBarData bar) {
            return peakSpot != null &&
                spot.x == peakSpot.x &&
                spot.y == peakSpot.y &&
                spot.y > 0;
          },
          getDotPainter:
              (FlSpot spot, double percent, LineChartBarData bar, int index) {
                return FlDotCirclePainter(
                  radius: 6,
                  color: onBlue,
                  strokeWidth: 3,
                  strokeColor: Colors.white.withValues(alpha: 0.35),
                );
              },
        ),
        belowBarData: BarAreaData(show: false),
      ),
      if (dashedSpots.length >= 2)
        LineChartBarData(
          spots: dashedSpots,
          isCurved: true,
          curveSmoothness: 0.38,
          color: Colors.white.withValues(alpha: 0.55),
          barWidth: 2,
          isStrokeCapRound: true,
          dashArray: const <int>[5, 6],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
    ];

    final int solidBarIndex = glowBars.length - (dashedSpots.length >= 2 ? 2 : 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.vendorHeroViolet,
            AppColors.vendorHeroBlue,
            AppColors.workflowDeep,
          ],
          stops: <double>[0.0, 0.45, 1.0],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.heroShadow.withValues(alpha: 0.42),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Sales trend',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: onBlue,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      best == null
                          ? 'No product sales in this range yet'
                          : 'Best seller: ${best!.productName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onBlueMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      'Gross',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onBlueMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      VendorAnalyticsTabPage._money(totalSales),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onBlue,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 168,
            child: LineChart(
              LineChartData(
                clipData: const FlClipData.all(),
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: math.max(1.0, (days.length - 1).toDouble()).clamp(1.0, 365.0).toDouble(),
                minY: 0,
                maxY: maxGross,
                extraLinesData: peakSpot == null
                    ? const ExtraLinesData()
                    : ExtraLinesData(
                        verticalLines: <VerticalLine>[
                          VerticalLine(
                            x: peakSpot.x,
                            color: Colors.white.withValues(alpha: 0.22),
                            strokeWidth: 1,
                          ),
                        ],
                      ),
                showingTooltipIndicators: peakSpot == null || peakDay == null
                    ? const <ShowingTooltipIndicators>[]
                    : <ShowingTooltipIndicators>[
                        ShowingTooltipIndicators(<LineBarSpot>[
                          LineBarSpot(
                            glowBars[solidBarIndex],
                            solidBarIndex,
                            peakSpot,
                          ),
                        ]),
                      ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  getTouchLineStart: (_, _) => 0,
                  getTouchLineEnd: (_, _) => double.infinity,
                  getTouchedSpotIndicator:
                      (LineChartBarData barData, List<int> spotIndexes) {
                    if (barData.barWidth > 3) {
                      return spotIndexes
                          .map((_) => null)
                          .toList(growable: false);
                    }
                    return spotIndexes.map((int index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: Colors.white.withValues(alpha: 0.28),
                          strokeWidth: 1,
                        ),
                        FlDotData(
                          getDotPainter:
                              (
                                FlSpot spot,
                                double percent,
                                LineChartBarData bar,
                                int index,
                              ) {
                                return FlDotCirclePainter(
                                  radius: 6,
                                  color: onBlue,
                                  strokeWidth: 3,
                                  strokeColor: Colors.white.withValues(
                                    alpha: 0.35,
                                  ),
                                );
                              },
                        ),
                      );
                    }).toList(growable: false);
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        const Color(0xE6282C34),
                    tooltipRoundedRadius: 14,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    tooltipMargin: 12,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (List<LineBarSpot> touched) {
                      return touched.map((LineBarSpot spot) {
                        // Skip neon glow underlays — only the core white stroke.
                        if (spot.bar.barWidth > 3) {
                          return null;
                        }
                        final int i = spot.x.round().clamp(0, days.length - 1);
                        final DailySalesPoint day = days[i];
                        final String value = day.grossLkr >= 1000
                            ? '${compactLkr(day.grossLkr)} LKR'
                            : 'Rs. ${day.grossLkr.toStringAsFixed(0)}';
                        return LineTooltipItem(
                          value,
                          const TextStyle(
                            color: onBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: -0.2,
                          ),
                        );
                      }).toList(growable: false);
                    },
                  ),
                ),
                lineBarsData: glowBars,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static int _peakIndex(List<DailySalesPoint> days) {
    if (days.isEmpty) {
      return -1;
    }
    int peak = 0;
    for (int i = 1; i < days.length; i++) {
      if (days[i].grossLkr > days[peak].grossLkr) {
        peak = i;
      }
    }
    if (days[peak].grossLkr <= 0) {
      return -1;
    }
    return peak;
  }

  static LineChartBarData _glowBar({
    required List<FlSpot> spots,
    required Color color,
    required double width,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.38,
      color: color,
      barWidth: width,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: VendorDashboardTheme.mutedText(context),
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: VendorDashboardTheme.mutedText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel({required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return _Panel(
      title: 'Smart insights',
      subtitle: 'Quick actions from live shop data',
      child: Column(
        children: <Widget>[
          for (int i = 0; i < insights.length; i++)
            _InsightRow(
              text: insights[i],
              icon: switch (i) {
                0 => Icons.insights_rounded,
                1 => Icons.inventory_2_rounded,
                2 => Icons.local_shipping_rounded,
                _ => Icons.bolt_rounded,
              },
              color: switch (i) {
                0 => cs.primary,
                1 => AppColors.pendingAmber,
                2 => AppColors.openGreen,
                _ => cs.tertiary,
              },
            ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: VendorDashboardTheme.primaryText(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryHealthPanel extends StatelessWidget {
  const _InventoryHealthPanel({required this.metrics, required this.products});

  final VendorCatalogMetricsSnapshot metrics;
  final List<VendorProduct> products;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool healthy = products.isEmpty && metrics.total > 0;

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
                      'Inventory health',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      healthy
                          ? 'All stock looks healthy'
                          : 'Stock issues that can affect orders',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: VendorDashboardTheme.mutedText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (healthy)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.openGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Healthy',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.openGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStat(
                  label: 'Active',
                  value: '${metrics.activeCount}',
                  icon: Icons.storefront_rounded,
                  color: AppColors.openGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Low',
                  value: '${metrics.lowCount}',
                  icon: Icons.battery_alert_rounded,
                  color: AppColors.pendingAmber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Out',
                  value: '${metrics.outCount}',
                  icon: Icons.production_quantity_limits_rounded,
                  color: AppColors.orderRejectRed,
                ),
              ),
            ],
          ),
          if (metrics.total == 0) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Add products to start tracking stock health.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: VendorDashboardTheme.mutedText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (products.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            for (int i = 0; i < products.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              _InventoryProductRow(product: products[i]),
            ],
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: VendorDashboardTheme.mutedText(context),
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryProductRow extends StatelessWidget {
  const _InventoryProductRow({required this.product});

  final VendorProduct product;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool out = product.stockQty == 0;
    final bool offline = !product.active;
    final Color color = out
        ? AppColors.orderRejectRed
        : offline
        ? theme.colorScheme.tertiary
        : AppColors.pendingAmber;
    final IconData icon = offline
        ? Icons.pause_circle_rounded
        : out
        ? Icons.error_outline_rounded
        : Icons.shopping_bag_rounded;
    final String status = offline
        ? 'Offline'
        : out
        ? 'Out of stock'
        : '${product.stockQty} left';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.itemsBoxFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: VendorDashboardTheme.primaryText(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
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
            VendorAnalyticsTabPage._money(row.grossLkr),
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
