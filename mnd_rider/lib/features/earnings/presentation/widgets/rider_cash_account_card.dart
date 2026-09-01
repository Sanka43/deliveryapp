import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/core/widgets/rider_branded_dialog.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/earnings/data/rider_cash_repository.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';

/// Cash the rider is carrying, how close it is to the limit that stops new
/// jobs, and the single button that asks admin to confirm a handover.
///
/// Replaces the old per-order "cash to remit" card: ride commission and shop
/// product cash are now handed over together in one settlement.
class RiderCashAccountCard extends ConsumerStatefulWidget {
  const RiderCashAccountCard({super.key});

  @override
  ConsumerState<RiderCashAccountCard> createState() =>
      _RiderCashAccountCardState();
}

class _RiderCashAccountCardState extends ConsumerState<RiderCashAccountCard> {
  bool _busy = false;

  Future<void> _requestSettlement(int owedLkr) async {
    final bool ok = await showRiderConfirmDialog(
      context,
      title: 'Hand over cash?',
      message: 'This tells Admin you are handing over '
          '${LkrFormat.money(owedLkr)} — shop totals plus ride commission. '
          'Your cash stays outstanding until Admin confirms they received it.',
      confirmLabel: 'Request confirm',
    );
    if (!ok) {
      return;
    }
    setState(() => _busy = true);
    final String? err = await ref
        .read(riderCashRepositoryProvider)
        .requestSettlement(method: 'bank');
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    showRiderSnackBar(
      context,
      err ?? 'Requested. Waiting for Admin to confirm the cash arrived.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final RiderProfile? profile =
        ref.watch(riderProfileStreamProvider).valueOrNull;
    final AsyncValue<List<RiderCashEntry>> entriesAsync =
        ref.watch(riderOutstandingCashProvider);
    final RiderCashSettlement? pending =
        ref.watch(riderPendingCashSettlementProvider).valueOrNull;
    final int maxLkr = ref.watch(riderMaxCashInHandProvider).valueOrNull ??
        kDefaultMaxCashInHandLkr;

    if (entriesAsync.hasError) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          userFacingError(
            entriesAsync.error!,
            fallback: 'Could not load your cash in hand.',
          ),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    final List<RiderCashEntry> entries =
        entriesAsync.valueOrNull ?? const <RiderCashEntry>[];
    final int cashInHand = profile?.cashInHandLkr ?? 0;
    final int owed = profile?.cashOwedToAdminLkr ?? 0;
    final bool held = profile?.isCashHeld ?? false;

    // Nothing collected and nothing pending — don't take up space.
    if (cashInHand <= 0 && entries.isEmpty && pending == null) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color accent = held ? AppColors.errorRed : AppColors.warningAmber;
    final double ratio =
        maxLkr <= 0 ? 0 : (cashInHand / maxLkr).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.account_balance_wallet_outlined,
                    size: 20, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cash in hand',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  LkrFormat.money(cashInHand),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700, color: accent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              held
                  ? 'Over the ${LkrFormat.money(maxLkr)} limit — no new rides '
                      'or deliveries until Admin confirms your handover.'
                  : 'Limit ${LkrFormat.money(maxLkr)}. New jobs stop once you '
                      'go above it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: held ? accent : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _OwedBreakdown(entries: entries, owed: owed),
            const SizedBox(height: 12),
            if (pending != null)
              _PendingBanner(settlement: pending)
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_busy || entries.isEmpty)
                      ? null
                      : () => _requestSettlement(owed),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_outlined, size: 18),
                  label: Text(
                    owed > 0
                        ? 'Hand over ${LkrFormat.money(owed)}'
                        : 'Settle collected cash',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Splits what admin is owed into the two buckets a rider recognises.
class _OwedBreakdown extends StatelessWidget {
  const _OwedBreakdown({required this.entries, required this.owed});

  final List<RiderCashEntry> entries;
  final int owed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    int shopTotal = 0;
    int commission = 0;
    for (final RiderCashEntry e in entries) {
      if (e.isRide) {
        commission += e.owedLkr;
      } else {
        shopTotal += e.owedLkr;
      }
    }

    Widget row(String label, String value, {bool strong = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        row('Shop totals', LkrFormat.money(shopTotal)),
        row('Ride commission', LkrFormat.money(commission)),
        const Divider(height: 12),
        row('Owed to admin', LkrFormat.money(owed), strong: true),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'The rest of the cash is yours to keep.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.settlement});

  final RiderCashSettlement settlement;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.hourglass_top, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Waiting for Admin to confirm '
              '${LkrFormat.money(settlement.amountLkr)}.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
