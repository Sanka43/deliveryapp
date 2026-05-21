import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/features/earnings/domain/rider_delivery_stats.dart';

class RiderEarningsStatsGrid extends StatelessWidget {
  const RiderEarningsStatsGrid({
    super.key,
    required this.stats,
    required this.weekGrowthPercent,
  });

  final RiderDeliveryStats stats;
  final double weekGrowthPercent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 520;
        final int crossAxisCount = wide ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: wide ? 1.35 : 1.2,
          children: <Widget>[
            _StatTile(
              icon: Icons.local_shipping_outlined,
              label: 'Today',
              value: '${stats.todayDeliveries}',
              caption: 'deliveries',
            ),
            _StatTile(
              icon: Icons.calendar_view_week_outlined,
              label: 'This week',
              value: '${stats.weekDeliveries}',
              caption: 'deliveries',
            ),
            _StatTile(
              icon: Icons.payments_outlined,
              label: 'Avg / trip',
              value: LkrFormat.moneyDecimal(stats.avgEarningPerTripLkr),
              caption: 'earnings',
            ),
            _StatTile(
              icon: Icons.trending_up_rounded,
              label: 'WoW growth',
              value:
                  '${weekGrowthPercent >= 0 ? '+' : ''}${weekGrowthPercent.toStringAsFixed(1)}%',
              caption: 'vs last week',
              accent: weekGrowthPercent >= 0
                  ? AppColors.onlineGreen
                  : const Color(0xFFDC2626),
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color highlight = accent ?? AppColors.primaryBlue;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlight.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: highlight),
            const Spacer(),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: highlight,
              ),
            ),
            Text(
              caption,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
