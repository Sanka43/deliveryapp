import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/logout_action_button.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_empty_state.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/admin/data/admin_orders_repository.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/user_role_provider.dart';

final AutoDisposeStreamProvider<List<AdminOrderRow>> adminOrdersListProvider =
    StreamProvider.autoDispose<List<AdminOrderRow>>((Ref ref) {
  final AsyncValue<String?> role = ref.watch(userRoleProvider);
  final bool isAdmin = role.maybeWhen(
    data: (String? r) => r?.trim().toLowerCase() == 'admin',
    orElse: () => false,
  );
  if (!isAdmin) {
    return Stream<List<AdminOrderRow>>.value(const <AdminOrderRow>[]);
  }
  return ref.watch(adminOrdersRepositoryProvider).watchRecentOrders();
});

class AdminOrdersPage extends ConsumerWidget {
  const AdminOrdersPage({super.key});

  static Future<void> _promptAssign(
    BuildContext context,
    WidgetRef ref,
    AdminOrderRow row,
  ) async {
    final TextEditingController c = TextEditingController(text: row.riderId ?? '');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Assign rider · ${row.referenceForDisplay}', maxLines: 1, overflow: TextOverflow.ellipsis),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            labelText: 'Rider Firebase UID',
            border: OutlineInputBorder(),
          ),
          autocorrect: false,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    final String? err = await ref.read(adminOrdersRepositoryProvider).assignRider(
          orderId: row.id,
          riderUid: c.text,
        );
    if (!context.mounted) {
      return;
    }
    if (err != null) {
      showMndSnackBar(context, err, variant: MndSnackBarVariant.error);
    } else {
      showMndSnackBar(
        context,
        'Rider assigned.',
        variant: MndSnackBarVariant.success,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminOrderRow>> orders = ref.watch(adminOrdersListProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(
        title: 'Orders (admin)',
        actions: const <Widget>[
          LogoutActionButton(),
        ],
      ),
      body: orders.when(
        data: (List<AdminOrderRow> list) {
          if (list.isEmpty) {
            return const MndEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No orders found',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int i) {
              final AdminOrderRow row = list[i];
              return MndPremiumCard(
                borderRadius: AppColors.cardRadiusMd,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            row.referenceForDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (row.trackingNumber?.trim().isNotEmpty ==
                                    true
                                ? Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w700,
                                    )
                                : Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    )),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'status: ${row.status}\nstore: ${row.vendorId}\ncustomer: ${row.customerId}\n'
                            'rider: ${row.riderId ?? '—'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Assign rider',
                      icon: const Icon(
                        Icons.delivery_dining_outlined,
                        color: AppColors.brandPrimary,
                      ),
                      onPressed: () => _promptAssign(context, ref, row),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
