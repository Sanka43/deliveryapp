import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/features/earnings/presentation/providers/rider_cash_hold_provider.dart';
import 'package:mnd_rider/features/shell/presentation/providers/rider_shell_tab_provider.dart';

/// Earnings is shell tab 2 — where the cash card and Settle button live.
const int _earningsTabIndex = 2;

/// Shown wherever a rider would otherwise expect jobs to appear, explaining
/// why they stopped. Renders nothing until the cash hold is actually on.
class RiderCashHoldBanner extends ConsumerWidget {
  const RiderCashHoldBanner({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(riderCashHoldActiveProvider)) {
      return const SizedBox.shrink();
    }
    final int owed = ref.watch(riderCashOwedProvider);
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: margin,
      child: Material(
        color: AppColors.errorRed,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () =>
              ref.read(riderShellTabIndexProvider.notifier).state =
                  _earningsTabIndex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                const Icon(Icons.pause_circle_filled,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Jobs paused — cash limit reached',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        owed > 0
                            ? 'Hand ${LkrFormat.money(owed)} to admin to start '
                                'receiving rides again.'
                            : 'Hand your collected cash to admin to start '
                                'receiving rides again.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
