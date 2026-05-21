import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_analytics.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_line_item.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_period_snapshot.dart';
import 'package:mnd_rider/features/earnings/presentation/providers/rider_earnings_from_orders_provider.dart';
import 'package:mnd_rider/features/earnings/presentation/widgets/rider_earnings_chart_card.dart';
import 'package:mnd_rider/features/earnings/presentation/widgets/rider_earnings_stats_grid.dart';
import 'package:mnd_rider/features/earnings/presentation/widgets/rider_wallet_card.dart';
import 'package:mnd_rider/features/earnings/presentation/widgets/rider_withdraw_sheet.dart';

class RiderEarningsPage extends ConsumerWidget {
  const RiderEarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RiderEarningsAnalytics analytics =
        ref.watch(riderEarningsAnalyticsProvider);
    final RiderEarningsSummary summary = ref.watch(riderEarningsSummaryProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                pinned: true,
                floating: true,
                title: const Text('Earnings'),
                bottom: const TabBar(
                  tabs: <Widget>[
                    Tab(text: 'Daily'),
                    Tab(text: 'Weekly'),
                    Tab(text: 'Monthly'),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      RiderWalletCard(
                        wallet: analytics.wallet,
                        onWithdraw: () => showRiderWithdrawSheet(context),
                        onHistory: () =>
                            context.push(RoutePaths.transactions),
                      ),
                      const SizedBox(height: 16),
                      _PeriodSummaryStrip(summary: summary),
                      const SizedBox(height: 16),
                      RiderEarningsStatsGrid(
                        stats: analytics.stats,
                        weekGrowthPercent: analytics.weekGrowthPercent,
                      ),
                      const SizedBox(height: 16),
                      RiderEarningsChartCard(
                        points: analytics.last7DaysChart,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: <Widget>[
              _EarningsPeriodBody(
                snapshot: ref.watch(riderDailyEarningsSnapshotProvider),
              ),
              _EarningsPeriodBody(
                snapshot: ref.watch(riderWeeklyEarningsSnapshotProvider),
              ),
              _EarningsPeriodBody(
                snapshot: ref.watch(riderMonthlyEarningsSnapshotProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodSummaryStrip extends StatelessWidget {
  const _PeriodSummaryStrip({required this.summary});

  final RiderEarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ChipMetric(
            label: 'Today',
            value: LkrFormat.moneyDecimal(summary.todayNet),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ChipMetric(
            label: 'Week',
            value: LkrFormat.moneyDecimal(summary.weekNet),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ChipMetric(
            label: 'Month',
            value: LkrFormat.moneyDecimal(summary.monthNet),
          ),
        ),
      ],
    );
  }
}

class _ChipMetric extends StatelessWidget {
  const _ChipMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsPeriodBody extends StatelessWidget {
  const _EarningsPeriodBody({required this.snapshot});

  final RiderEarningsPeriodSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        32 + MediaQuery.paddingOf(context).bottom + 72,
      ),
      children: <Widget>[
        Text(
          snapshot.rangeTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          snapshot.rangeSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Net total', style: theme.textTheme.labelLarge),
                      Text(
                        LkrFormat.moneyDecimal(snapshot.netTotal),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${snapshot.tripCount} trips',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Recent deliveries',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (snapshot.lineItems.isEmpty)
          Text(
            'No completed deliveries in this period.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...snapshot.lineItems.map(
            (RiderEarningsLineItem item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.surfaceMuted),
                ),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                trailing: Text(
                  LkrFormat.moneyDecimal(item.amount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
