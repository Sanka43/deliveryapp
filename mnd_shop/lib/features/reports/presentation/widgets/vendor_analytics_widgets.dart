import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_catalog_metrics_snapshot.dart';
import 'package:mnd_shop/features/dashboard/presentation/widgets/vendor_dashboard_ui.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';
import 'package:mnd_shop/features/reports/data/vendor_stats_repository.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_snapshot.dart';

String vendorAnalyticsFormatLkr(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
  return v.toStringAsFixed(0);
}

String vendorAnalyticsFormatMoney(double v) => 'Rs. ${v.toStringAsFixed(2)}';

class VendorAnalyticsRangeSelector extends StatelessWidget {
  const VendorAnalyticsRangeSelector({
    super.key,
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
              child: VendorAnalyticsRangePill(
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

class VendorAnalyticsRangePill extends StatelessWidget {
  const VendorAnalyticsRangePill({
    super.key,
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

class VendorAnalyticsSalesTrendHero extends StatelessWidget {
  const VendorAnalyticsSalesTrendHero({
    super.key,
    required this.days,
    required this.spots,
    required this.maxGross,
    required this.totalSales,
    required this.best,
    required this.compactLkr,
    required this.formatMoney,
    this.title = 'Sales timeline',
    this.timelineChips = const <String>[],
    this.chartHeight = 176,
  });

  final List<DailySalesPoint> days;
  final List<FlSpot> spots;
  final double maxGross;
  final double totalSales;
  final ProductSalesPoint? best;
  final String Function(double) compactLkr;
  final String Function(double) formatMoney;
  final String title;
  final List<String> timelineChips;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const Color onBlue = Colors.white;
    final Color onBlueMuted = Colors.white.withValues(alpha: 0.72);

    final int peakIndex = _peakIndex(days);
    final List<FlSpot> solidSpots = peakIndex < 0
        ? spots
        : spots.sublist(0, peakIndex + 1);
    final List<FlSpot> dashedSpots =
        peakIndex < 0 || peakIndex >= spots.length - 1
        ? const <FlSpot>[]
        : spots.sublist(peakIndex);
    final FlSpot? peakSpot = peakIndex >= 0 && peakIndex < spots.length
        ? spots[peakIndex]
        : null;
    final DailySalesPoint? peakDay =
        peakIndex >= 0 && peakIndex < days.length ? days[peakIndex] : null;

    final List<LineChartBarData> glowBars = <LineChartBarData>[
      _glowBar(
        spots: solidSpots,
        color: const Color(0xFF7EB6FF).withValues(alpha: 0.28),
        width: 16,
      ),
      _glowBar(
        spots: solidSpots,
        color: Colors.white.withValues(alpha: 0.32),
        width: 8,
      ),
      LineChartBarData(
        spots: solidSpots,
        isCurved: true,
        curveSmoothness: 0.4,
        color: onBlue,
        barWidth: 2.8,
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
                  radius: 6.5,
                  color: onBlue,
                  strokeWidth: 3.5,
                  strokeColor: Colors.white.withValues(alpha: 0.4),
                );
              },
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
      if (dashedSpots.length >= 2)
        LineChartBarData(
          spots: dashedSpots,
          isCurved: true,
          curveSmoothness: 0.4,
          color: Colors.white.withValues(alpha: 0.5),
          barWidth: 2,
          isStrokeCapRound: true,
          dashArray: const <int>[5, 6],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
    ];

    final int solidBarIndex =
        glowBars.length - (dashedSpots.length >= 2 ? 2 : 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.vendorHeroViolet,
            AppColors.vendorHeroBlue,
            AppColors.workflowDeep,
          ],
          stops: <double>[0.0, 0.5, 1.0],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.heroShadow.withValues(alpha: 0.4),
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
                      title,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
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
                      formatMoney(totalSales),
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
          if (timelineChips.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String chip in timelineChips)
                  _VendorAnalyticsTimelineChip(label: chip),
              ],
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: chartHeight,
            child: LineChart(
              LineChartData(
                clipData: const FlClipData.all(),
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: math
                    .max(1.0, (days.length - 1).toDouble())
                    .clamp(1.0, 365.0)
                    .toDouble(),
                minY: 0,
                maxY: maxGross,
                extraLinesData: peakSpot == null
                    ? const ExtraLinesData()
                    : ExtraLinesData(
                        verticalLines: <VerticalLine>[
                          VerticalLine(
                            x: peakSpot.x,
                            color: Colors.white.withValues(alpha: 0.2),
                            strokeWidth: 1,
                            dashArray: const <int>[3, 4],
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
                                  radius: 6.5,
                                  color: onBlue,
                                  strokeWidth: 3,
                                  strokeColor: Colors.white.withValues(
                                    alpha: 0.4,
                                  ),
                                );
                              },
                        ),
                      );
                    }).toList(growable: false);
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xE6282C34),
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
                        if (spot.bar.barWidth > 3) {
                          return null;
                        }
                        final int i = spot.x.round().clamp(0, days.length - 1);
                        final DailySalesPoint day = days[i];
                        final String value = day.grossLkr >= 1000
                            ? '${compactLkr(day.grossLkr)} LKR'
                            : 'Rs. ${day.grossLkr.toStringAsFixed(0)}';
                        return LineTooltipItem(
                          '${day.shortLabel}\n$value',
                          const TextStyle(
                            color: onBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            height: 1.35,
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
      curveSmoothness: 0.4,
      color: color,
      barWidth: width,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}

class _VendorAnalyticsTimelineChip extends StatelessWidget {
  const _VendorAnalyticsTimelineChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.88),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class VendorAnalyticsMetricTile extends StatelessWidget {
  const VendorAnalyticsMetricTile({
    super.key,
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

class VendorAnalyticsInsightsPanel extends StatelessWidget {
  const VendorAnalyticsInsightsPanel({super.key, required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return _VendorAnalyticsPanel(
      title: 'Smart insights',
      subtitle: 'Quick actions from live shop data',
      child: Column(
        children: <Widget>[
          for (int i = 0; i < insights.length; i++)
            _VendorAnalyticsInsightRow(
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

class _VendorAnalyticsPanel extends StatelessWidget {
  const _VendorAnalyticsPanel({
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

class _VendorAnalyticsInsightRow extends StatelessWidget {
  const _VendorAnalyticsInsightRow({
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

class VendorAnalyticsInventoryHealthPanel extends StatelessWidget {
  const VendorAnalyticsInventoryHealthPanel({
    super.key,
    required this.metrics,
    required this.products,
  });

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
                child: _VendorAnalyticsMiniStat(
                  label: 'Active',
                  value: '${metrics.activeCount}',
                  icon: Icons.storefront_rounded,
                  color: AppColors.openGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VendorAnalyticsMiniStat(
                  label: 'Low',
                  value: '${metrics.lowCount}',
                  icon: Icons.battery_alert_rounded,
                  color: AppColors.pendingAmber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VendorAnalyticsMiniStat(
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
              _VendorAnalyticsInventoryProductRow(product: products[i]),
            ],
          ],
        ],
      ),
    );
  }
}

class _VendorAnalyticsMiniStat extends StatelessWidget {
  const _VendorAnalyticsMiniStat({
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

class _VendorAnalyticsInventoryProductRow extends StatelessWidget {
  const _VendorAnalyticsInventoryProductRow({required this.product});

  final VendorProduct product;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool out = product.manageStock && product.stockQty == 0;
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
        : !product.manageStock
        ? 'Not tracked'
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
