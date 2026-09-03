import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/core/widgets/rider_empty_state.dart';
import 'package:mnd_rider/core/widgets/rider_error_state.dart';
import 'package:mnd_rider/core/widgets/rider_skeleton.dart';
import 'package:mnd_rider/features/earnings/domain/rider_transaction.dart';
import 'package:mnd_rider/features/earnings/presentation/providers/rider_earnings_from_orders_provider.dart';

class RiderTransactionsPage extends ConsumerWidget {
  const RiderTransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RiderTransaction>> txns =
        ref.watch(riderTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction history')),
      body: RefreshIndicator(
        color: AppColors.primaryBlue,
        onRefresh: () async {
          ref.invalidate(riderTransactionsProvider);
        },
        child: txns.when(
          loading: () => const _TransactionsScroll(
            child: RiderSkeletonList(count: 6),
          ),
          error: (Object e, _) => _TransactionsScroll(
            child: RiderErrorState(
              message: userFacingError(e, fallback: 'Could not load transactions.'),
              onRetry: () => ref.invalidate(riderTransactionsProvider),
            ),
          ),
          data: (List<RiderTransaction> list) {
            if (list.isEmpty) {
              return const _TransactionsScroll(
                child: RiderEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                  subtitle: 'Complete deliveries to earn.',
                ),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (BuildContext context, int index) =>
                  _TransactionCard(txn: list[index]),
            );
          },
        ),
      ),
    );
  }
}

/// Keeps loading/error/empty states pull-to-refreshable and scrollable even
/// when there's no list content to scroll.
class _TransactionsScroll extends StatelessWidget {
  const _TransactionsScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.txn});

  final RiderTransaction txn;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool credit = txn.isCredit;
    final Color amountColor = credit ? AppColors.onlineGreen : cs.error;
    final String when = txn.createdAt != null
        ? DateFormat('d MMM · HH:mm').format(txn.createdAt!)
        : '';

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: amountColor.withValues(alpha: 0.12),
              child: Icon(
                credit ? Icons.add_rounded : Icons.remove_rounded,
                color: amountColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    txn.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    <String>[txn.subtitle, when]
                        .where((String s) => s.isNotEmpty)
                        .join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${credit ? '+' : ''}${LkrFormat.moneyDecimal(txn.amountLkr.abs())}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                Text(_txnStatusLabel(txn), style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _txnStatusLabel(RiderTransaction t) {
  switch (t.status) {
    case RiderTransactionStatus.pending:
      return 'Pending';
    case RiderTransactionStatus.failed:
      return 'Failed';
    case RiderTransactionStatus.cancelled:
      return t.type == RiderTransactionType.withdrawal ? 'Rejected' : 'Cancelled';
    case RiderTransactionStatus.completed:
      return t.type == RiderTransactionType.withdrawal ? 'Paid' : 'Completed';
  }
}
