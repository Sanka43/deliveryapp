import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_snapshot.dart';
import 'package:mnd_shop/features/reports/presentation/providers/vendor_reports_provider.dart';

class VendorReportsPage extends ConsumerWidget {
  const VendorReportsPage({super.key});

  static String _compactLkr(double v) {
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)}M';
    }
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(0)}k';
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VendorReportSnapshot data = ref.watch(vendorReportsProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final List<DailySalesPoint> days = data.last7Days;
    final double maxGross = days.isEmpty
        ? 1
        : days.map((DailySalesPoint e) => e.grossLkr).reduce(math.max) * 1.12;
    final int maxOrders = days.isEmpty
        ? 1
        : days.map((DailySalesPoint e) => e.orders).reduce(math.max) + 2;

    final List<FlSpot> grossSpots = <FlSpot>[
      for (int i = 0; i < days.length; i++) FlSpot(i.toDouble(), days[i].grossLkr),
    ];

    final List<Color> pieColors = <Color>[
      AppColors.primaryBlue,
      AppColors.openGreen,
      AppColors.pendingAmber,
      cs.tertiary,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: <Widget>[
          Text(
            'Demo data — replace with live analytics when orders are aggregated.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            'Sales (last 7 days)',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _ChartCard(
            height: 240,
            child: LineChart(
              LineChartData(
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxGross > 0 ? maxGross / 4 : 1,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int i = value.round();
                        if (i < 0 || i >= days.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            days[i].shortLabel,
                            style: theme.textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxGross > 0 ? maxGross / 4 : 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          _compactLkr(value),
                          style: theme.textTheme.labelSmall,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                ),
                minX: 0,
                maxX: (days.length - 1).toDouble().clamp(0, 100),
                minY: 0,
                maxY: maxGross,
                lineBarsData: <LineChartBarData>[
                  LineChartBarData(
                    spots: grossSpots,
                    isCurved: true,
                    curveSmoothness: 0.28,
                    color: AppColors.primaryBlue,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Orders per day',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _ChartCard(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxOrders.toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1, maxOrders / 4).toDouble(),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int i = value.toInt();
                        if (i < 0 || i >= days.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(days[i].shortLabel, style: theme.textTheme.labelSmall),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value != value.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: theme.textTheme.labelSmall,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                ),
                barGroups: <BarChartGroupData>[
                  for (int i = 0; i < days.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: days[i].orders.toDouble(),
                          width: 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          color: AppColors.openGreen,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Revenue by category (period)',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _ChartCard(
            height: 260,
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 48,
                      sections: <PieChartSectionData>[
                        for (int i = 0; i < data.categoryLabels.length; i++)
                          PieChartSectionData(
                            color: pieColors[i % pieColors.length],
                            value: data.categoryValuesLkr[i],
                            title: _pieTitle(data, i),
                            radius: 54,
                            titleStyle: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              shadows: const <Shadow>[
                                Shadow(blurRadius: 2, color: Colors.black45),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (int i = 0; i < data.categoryLabels.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: pieColors[i % pieColors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data.categoryLabels[i],
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _pieTitle(VendorReportSnapshot data, int i) {
    final double total = data.totalCategoryLkr;
    if (total <= 0) {
      return '';
    }
    final double pct = 100 * data.categoryValuesLkr[i] / total;
    return '${pct.round()}%';
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(height: height, width: double.infinity, child: child),
      ),
    );
  }
}
