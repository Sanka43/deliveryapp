import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_analytics.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_line_item.dart';
import 'package:mnd_rider/features/earnings/domain/rider_earnings_period_snapshot.dart';
import 'package:mnd_rider/features/earnings/domain/rider_wallet.dart';
import 'package:mnd_rider/features/earnings/domain/rider_withdrawal.dart';
import 'package:mnd_rider/features/earnings/presentation/providers/rider_earnings_from_orders_provider.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/earnings/presentation/widgets/rider_cash_account_card.dart';
import 'package:mnd_rider/features/earnings/presentation/widgets/rider_earnings_chart_card.dart';
import 'package:mnd_rider/features/earnings/presentation/widgets/rider_wallet_card.dart';
import 'package:mnd_rider/features/earnings/presentation/widgets/rider_withdraw_sheet.dart';
import 'package:mnd_rider/features/shell/presentation/widgets/rider_floating_nav_bar.dart';

enum _EarningsPeriod { daily, weekly, monthly }

/// Wallet + period activity — one scroll, no nested tabs/stats clutter.
class RiderEarningsPage extends ConsumerStatefulWidget {
  const RiderEarningsPage({super.key});

  @override
  ConsumerState<RiderEarningsPage> createState() => _RiderEarningsPageState();
}

class _RiderEarningsPageState extends ConsumerState<RiderEarningsPage> {
  _EarningsPeriod _period = _EarningsPeriod.daily;

  RiderEarningsPeriodSnapshot _snapshotFor(_EarningsPeriod period) {
    switch (period) {
      case _EarningsPeriod.daily:
        return ref.watch(riderDailyEarningsSnapshotProvider);
      case _EarningsPeriod.weekly:
        return ref.watch(riderWeeklyEarningsSnapshotProvider);
      case _EarningsPeriod.monthly:
        return ref.watch(riderMonthlyEarningsSnapshotProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RiderEarningsAnalytics analytics = ref.watch(
      riderEarningsAnalyticsProvider,
    );
    final RiderEarningsPeriodSnapshot snapshot = _snapshotFor(_period);

    final AsyncValue<RiderWallet> walletAsync = ref.watch(riderWalletProvider);
    final AsyncValue<List<RiderWithdrawal>> withdrawalsAsync = ref.watch(
      riderWithdrawalsProvider,
    );
    final RiderWallet wallet =
        walletAsync.valueOrNull ?? const RiderWallet.empty();
    final bool walletReady = walletAsync.hasValue && !walletAsync.hasError;
    final String? walletError = walletAsync.hasError
        ? 'Could not load wallet. Pull to refresh or try again.'
        : null;
    final bool creditMismatch =
        walletReady &&
        wallet.lifetimeEarnedLkr <= 0 &&
        snapshot.tripCount > 0 &&
        snapshot.netTotal > 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppColors.primaryBlue,
        onRefresh: () async {
          ref.invalidate(riderWalletProvider);
          ref.invalidate(riderWithdrawalsProvider);
          ref.invalidate(riderDeliveredHistoryProvider);
          ref.invalidate(riderEarningsCompletedTripsProvider);
          ref.invalidate(riderDailyEarningsAggregateProvider);
          ref.invalidate(riderWeeklyEarningsAggregateProvider);
          ref.invalidate(riderMonthlyEarningsAggregateProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              title: const Text('Earnings'),
              centerTitle: false,
              actions: <Widget>[
                TextButton(
                  onPressed: () => context.push(RoutePaths.transactions),
                  child: const Text('History'),
                ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                8,
                AppSpacing.screenPadding,
                16 + riderFloatingNavTotalHeight(context),
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  RiderWalletCard(
                    wallet: wallet,
                    loading: walletAsync.isLoading,
                    errorMessage: walletError,
                    withdrawEnabled: walletReady,
                    onWithdraw: () => showRiderWithdrawSheet(context),
                    onHistory: () => context.push(RoutePaths.transactions),
                  ),
                  if (creditMismatch)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _InlineAlert(
                        message:
                            'Completed trips are showing here, but the wallet has not been credited yet. If this lasts more than a few minutes, contact support with the order number.',
                      ),
                    ),
                  const RiderCashAccountCard(),
                  _WithdrawalsSection(async: withdrawalsAsync),
                  const SizedBox(height: AppSpacing.sectionGap),
                  Text(
                    'Activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PeriodSwitcher(
                    value: _period,
                    onChanged: (_EarningsPeriod next) {
                      setState(() => _period = next);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PeriodSummaryCard(snapshot: snapshot),
                  const SizedBox(height: AppSpacing.md),
                  if (_period == _EarningsPeriod.weekly) ...<Widget>[
                    RiderEarningsChartCard(points: analytics.last7DaysChart),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    'Activity',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (snapshot.lineItems.isEmpty)
                    _EmptyDeliveries(
                      message: 'No completed deliveries or rides in this period.',
                    )
                  else
                    ...snapshot.lineItems.map(
                      (RiderEarningsLineItem item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _DeliveryTile(item: item),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSwitcher extends StatelessWidget {
  const _PeriodSwitcher({required this.value, required this.onChanged});

  final _EarningsPeriod value;
  final ValueChanged<_EarningsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: <Widget>[
            for (final _EarningsPeriod period in _EarningsPeriod.values)
              Expanded(
                child: _PeriodChip(
                  label: switch (period) {
                    _EarningsPeriod.daily => 'Daily',
                    _EarningsPeriod.weekly => 'Weekly',
                    _EarningsPeriod.monthly => 'Monthly',
                  },
                  selected: value == period,
                  onTap: () => onChanged(period),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
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
    return Material(
      color: selected ? AppColors.primaryBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius - 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius - 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard({required this.snapshot});

  final RiderEarningsPeriodSnapshot snapshot;

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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              snapshot.rangeTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              snapshot.rangeSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Net earnings',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LkrFormat.moneyDecimal(snapshot.netTotal),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      '${snapshot.tripCount} trips',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
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

class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({required this.item});

  final RiderEarningsLineItem item;

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.kind == RiderEarningsItemKind.ride
                    ? Icons.directions_car_outlined
                    : Icons.local_shipping_outlined,
                size: 20,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              LkrFormat.moneyDecimal(item.amount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDeliveries extends StatelessWidget {
  const _EmptyDeliveries({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _WithdrawalsSection extends StatelessWidget {
  const _WithdrawalsSection({required this.async});

  final AsyncValue<List<RiderWithdrawal>> async;

  String _statusLabel(RiderWithdrawalStatus status) {
    switch (status) {
      case RiderWithdrawalStatus.pending:
        return 'Pending';
      case RiderWithdrawalStatus.approved:
        return 'Approved';
      case RiderWithdrawalStatus.rejected:
        return 'Rejected — refunded';
      case RiderWithdrawalStatus.paid:
        return 'Paid';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final List<RiderWithdrawal> rows =
        async.valueOrNull ?? const <RiderWithdrawal>[];
    if (async.hasError) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          'Could not load withdrawal requests.',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
        ),
      );
    }
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Payout requests',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...rows
              .take(8)
              .map(
                (RiderWithdrawal w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${LkrFormat.moneyDecimal(w.amountLkr)} · ${w.payoutMethod}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        _statusLabel(w.status),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: w.status == RiderWithdrawalStatus.rejected
                              ? cs.error
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Compact tinted banner for a warning that isn't worth a full error state.
class _InlineAlert extends StatelessWidget {
  const _InlineAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = AppColors.warningAmber;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline_rounded, size: 18, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
