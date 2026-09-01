import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/features/earnings/domain/rider_wallet.dart';

class RiderWalletCard extends StatelessWidget {
  const RiderWalletCard({
    super.key,
    required this.wallet,
    required this.onWithdraw,
    required this.onHistory,
    this.loading = false,
    this.errorMessage,
    this.withdrawEnabled = true,
  });

  final RiderWallet wallet;
  final VoidCallback onWithdraw;
  final VoidCallback onHistory;
  final bool loading;
  final String? errorMessage;
  final bool withdrawEnabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (errorMessage != null) ...<Widget>[
              Text(
                errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              'Available balance',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'From online-paid (PayHere) jobs only',
              style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              LkrFormat.moneyDecimal(wallet.balanceLkr),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Meta(
                    label: 'Lifetime',
                    value: LkrFormat.moneyDecimal(wallet.lifetimeEarnedLkr),
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: cs.outlineVariant,
                ),
                Expanded(
                  child: _Meta(
                    label: 'Pending',
                    value: LkrFormat.moneyDecimal(wallet.pendingWithdrawalLkr),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: withdrawEnabled && !loading ? onWithdraw : null,
                    child: const Text('Withdraw'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onHistory,
                    child: const Text('Ledger'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
