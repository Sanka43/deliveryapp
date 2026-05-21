import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
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
      body: txns.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Could not load: $e')),
        data: (List<RiderTransaction> list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                'No transactions yet.\nComplete deliveries to earn.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final RiderTransaction t = list[index];
              final bool credit = t.isCredit;
              final Color amountColor =
                  credit ? AppColors.onlineGreen : const Color(0xFFDC2626);
              final String when = t.createdAt != null
                  ? DateFormat('d MMM · HH:mm').format(t.createdAt!)
                  : '';

              return ListTile(
                tileColor: AppColors.surfaceMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: CircleAvatar(
                  backgroundColor: amountColor.withValues(alpha: 0.12),
                  child: Icon(
                    credit ? Icons.add_rounded : Icons.remove_rounded,
                    color: amountColor,
                  ),
                ),
                title: Text(t.title),
                subtitle: Text(
                  <String>[t.subtitle, when]
                      .where((String s) => s.isNotEmpty)
                      .join(' · '),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${credit ? '+' : ''}${LkrFormat.moneyDecimal(t.amountLkr.abs())}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: amountColor,
                          ),
                    ),
                    Text(
                      t.status.name,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
