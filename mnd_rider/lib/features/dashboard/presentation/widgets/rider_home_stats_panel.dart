import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_home_stats_provider.dart';

class RiderHomeStatsPanel extends StatelessWidget {
  const RiderHomeStatsPanel({
    super.key,
    required this.stats,
    required this.isOnline,
    required this.onOnlineChanged,
    this.animationOffset = 0,
  });

  final RiderHomeStats stats;
  final bool isOnline;
  final ValueChanged<bool> onOnlineChanged;
  final double animationOffset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 24, end: 0),
      duration: Duration(milliseconds: 420 + (animationOffset * 60).round()),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double slide, Widget? child) {
        return Transform.translate(
          offset: Offset(0, slide),
          child: Opacity(
            opacity: (24 - slide) / 24,
            child: child,
          ),
        );
      },
      child: Material(
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        color: theme.colorScheme.surface.withValues(alpha: 0.98),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            20 + MediaQuery.paddingOf(context).bottom + 72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _OnlineRow(isOnline: isOnline, onChanged: onOnlineChanged),
              const SizedBox(height: 16),
              _EarningsHeroCard(amount: LkrFormat.moneyDecimal(stats.todayEarningsLkr)),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MiniStatCard(
                      icon: Icons.local_shipping_outlined,
                      label: 'Active',
                      value: '${stats.activeOrderCount}',
                      accent: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Done today',
                      value: '${stats.completedToday}',
                      accent: AppColors.onlineGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStatCard(
                      icon: Icons.radar,
                      label: 'Open jobs',
                      value: '${stats.openJobsCount}',
                      accent: AppColors.warningAmber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnlineRow extends StatelessWidget {
  const _OnlineRow({required this.isOnline, required this.onChanged});

  final bool isOnline;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.onlineGreen.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline
              ? AppColors.onlineGreen.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(
          isOnline ? 'You\'re online' : 'Go online for jobs',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          isOnline ? 'Receiving delivery requests' : 'Turn on to get offers',
          style: theme.textTheme.bodySmall,
        ),
        value: isOnline,
        activeThumbColor: AppColors.onlineGreen,
        onChanged: onChanged,
      ),
    );
  }
}

class _EarningsHeroCard extends StatelessWidget {
  const _EarningsHeroCard({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1D4ED8), AppColors.primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            const Icon(Icons.payments_outlined, color: Colors.white, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Today\'s earnings',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amount,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: accent),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
