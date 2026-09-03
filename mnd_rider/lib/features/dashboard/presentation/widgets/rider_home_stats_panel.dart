import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_home_stats_provider.dart';
import 'package:mnd_rider/features/shell/presentation/providers/rider_shell_tab_provider.dart';

/// Compact ops dock — status + Active / Done / Open metrics.
class RiderHomeStatsPanel extends ConsumerWidget {
  const RiderHomeStatsPanel({
    super.key,
    required this.stats,
    required this.isOnline,
  });

  final RiderHomeStats stats;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool hasOpen = stats.openJobsCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: cs.surface,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _OpsHeader(
                isOnline: isOnline,
                openJobsCount: stats.openJobsCount,
                onClaimTap: hasOpen
                    ? () {
                        ref.read(riderShellTabIndexProvider.notifier).state = 1;
                      }
                    : null,
              ),
              Divider(height: 1, thickness: 1, color: cs.outlineVariant),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _Metric(
                        value: stats.activeOrderCount,
                        label: 'Active',
                      ),
                    ),
                    _Hairline(),
                    Expanded(
                      child: _Metric(
                        value: stats.completedToday,
                        label: 'Done',
                      ),
                    ),
                    _Hairline(),
                    Expanded(
                      child: _Metric(
                        value: stats.openJobsCount,
                        label: 'Open',
                        emphasize: hasOpen,
                        onTap: () {
                          ref.read(riderShellTabIndexProvider.notifier).state =
                              1;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpsHeader extends StatelessWidget {
  const _OpsHeader({
    required this.isOnline,
    required this.openJobsCount,
    required this.onClaimTap,
  });

  final bool isOnline;
  final int openJobsCount;
  final VoidCallback? onClaimTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool hasOpen = openJobsCount > 0;

    if (isOnline && hasOpen) {
      return Material(
        color: AppColors.primaryBlue.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: InkWell(
          onTap: onClaimTap,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                      children: <InlineSpan>[
                        TextSpan(text: '$openJobsCount open nearby'),
                        TextSpan(
                          text: '  ·  claim now',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.primaryBlue,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Color dot =
        isOnline ? AppColors.onlineGreen : AppColors.offlineGrey;
    final String label = isOnline
        ? 'Online — waiting for offers'
        : 'Offline — go online to get jobs';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              boxShadow: isOnline
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.onlineGreen.withValues(alpha: 0.45),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.2,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: 1,
      height: 36,
      color: cs.outlineVariant,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    this.emphasize = false,
    this.onTap,
  });

  final int value;
  final String label;
  final bool emphasize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color valueColor =
        emphasize ? AppColors.primaryBlue : cs.onSurface;

    final Widget body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      child: Column(
        children: <Widget>[
          Text(
            '$value',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontSize: 26,
              height: 1,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return body;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: body,
      ),
    );
  }
}
