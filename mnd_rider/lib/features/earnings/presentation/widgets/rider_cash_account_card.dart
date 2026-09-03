import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/earnings/data/rider_cash_repository.dart';
import 'package:mnd_rider/features/earnings/presentation/widgets/rider_cash_handover_confirm_dialog.dart';
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

  Future<void> _requestSettlement(
    int owedLkr,
    int yourEarningLkr,
    List<RiderCashBreakdownLine> breakdown,
  ) async {
    final bool ok = await showRiderCashHandoverConfirmDialog(
      context,
      owedLkr: owedLkr,
      yourEarningLkr: yourEarningLkr,
      breakdown: breakdown,
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
    final int yourEarning = (cashInHand - owed).clamp(0, cashInHand);

    int foodCash = 0;
    int rideCash = 0;
    int productCash = 0;
    int serviceCharge = 0;
    int commission = 0;
    for (final RiderCashEntry e in entries) {
      if (e.isRide) {
        rideCash += e.cashLkr;
      } else {
        foodCash += e.cashLkr;
      }
      productCash += e.productCashLkr;
      serviceCharge += e.serviceChargeLkr;
      commission += e.rideCommissionLkr;
    }
    // Service charge is folded into the shop product cost line — both are
    // money that ends up with the shop/platform, not a separate rider concern.
    final int shopAmount = productCash + serviceCharge;
    final List<RiderCashBreakdownLine> owedBreakdown = <RiderCashBreakdownLine>[
      if (shopAmount > 0)
        RiderCashBreakdownLine(label: 'Shop product cost', amountLkr: shopAmount),
      if (commission > 0)
        RiderCashBreakdownLine(label: 'Rider commission', amountLkr: commission),
    ];

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
            if (entries.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _SourceSplit(foodCashLkr: foodCash, rideCashLkr: rideCash),
            ],
            const SizedBox(height: 12),
            _OwedBreakdown(
              productCashLkr: productCash,
              serviceChargeLkr: serviceCharge,
              rideCommissionLkr: commission,
              owed: owed,
              yourEarningLkr: yourEarning,
            ),
            const SizedBox(height: 12),
            if (pending != null)
              _PendingBanner(settlement: pending)
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_busy || entries.isEmpty)
                      ? null
                      : () => _requestSettlement(owed, yourEarning, owedBreakdown),
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

/// Cash in hand split by where it came from — a rider mixing food deliveries
/// and passenger rides carries one running total, but recognises the two
/// sources separately.
class _SourceSplit extends StatelessWidget {
  const _SourceSplit({required this.foodCashLkr, required this.rideCashLkr});

  final int foodCashLkr;
  final int rideCashLkr;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    Widget stat(String label, int amountLkr) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              LkrFormat.money(amountLkr),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          stat('Food deliveries', foodCashLkr),
          Container(width: 1, height: 30, color: cs.outlineVariant),
          const SizedBox(width: 12),
          stat('Rides', rideCashLkr),
        ],
      ),
    );
  }
}

/// The owed breakdown (shop product cost + service charge folded into one
/// line, rider commission on its own), plus the rider's own kept earning
/// shown with equal prominence — not just a caption underneath.
class _OwedBreakdown extends StatelessWidget {
  const _OwedBreakdown({
    required this.productCashLkr,
    required this.serviceChargeLkr,
    required this.rideCommissionLkr,
    required this.owed,
    required this.yourEarningLkr,
  });

  final int productCashLkr;
  final int serviceChargeLkr;
  final int rideCommissionLkr;
  final int owed;
  final int yourEarningLkr;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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

    // Service charge is folded into the shop product cost line — both are
    // money that ends up with the shop/platform, not a separate rider concern.
    final int shopAmount = productCashLkr + serviceChargeLkr;
    return Column(
      children: <Widget>[
        if (shopAmount > 0) row('Shop product cost', LkrFormat.money(shopAmount)),
        if (rideCommissionLkr > 0) row('Rider commission', LkrFormat.money(rideCommissionLkr)),
        const Divider(height: 12),
        row('Owed to admin', LkrFormat.money(owed), strong: true),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.onlineGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Your earning',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                LkrFormat.money(yourEarningLkr),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.onlineGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
