import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/widgets/rider_empty_state.dart';
import 'package:mnd_rider/core/widgets/rider_large_card.dart';
import 'package:mnd_rider/core/widgets/rider_section_title.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/orders/presentation/providers/rider_active_order_provider.dart';

/// Assigned and active orders (delivery requests overlay is global).
class RiderOrdersTabPage extends ConsumerWidget {
  const RiderOrdersTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isOnline = ref.watch(riderDashboardProvider).isOnline;
    final bool approved = ref.watch(riderIsApprovedToDriveProvider);
    final AsyncValue<List<RiderAssignedOrder>> assigned =
        ref.watch(assignedRiderOrdersProvider);
    final String? activeId = ref.watch(activeRiderOrderIdProvider);

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(assignedRiderOrdersProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            8,
            AppSpacing.screenPadding,
            24 + MediaQuery.paddingOf(context).bottom + 72,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!approved)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.warningAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.warningAmber.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.hourglass_top_outlined,
                          color: AppColors.warningAmber,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Admin approval is required before you can go online and accept new deliveries.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!approved) const SizedBox(height: AppSpacing.sectionGap),
              if (approved && !isOnline)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Go online from Home to receive live delivery offers.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (approved && !isOnline) const SizedBox(height: AppSpacing.sectionGap),
              if (activeId != null) ...<Widget>[
                const RiderSectionTitle('Active delivery'),
                const SizedBox(height: 10),
                ref.watch(riderOrderDetailProvider(activeId)).when(
                      data: (RiderOrderDetail? order) {
                        if (order == null) {
                          return const SizedBox.shrink();
                        }
                        return RiderLargeCard(
                          borderColor: AppColors.primaryBlue.withValues(alpha: 0.35),
                          onTap: () => context.push(
                            '${RoutePaths.trip}/${order.id}',
                            extra: order,
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              order.storeName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${order.referenceForDisplay} · ${order.status}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (Object e, _) => Text('$e'),
                    ),
                const SizedBox(height: AppSpacing.sectionGap),
              ],
              RiderSectionTitle(
                'My orders',
                trailing: TextButton(
                  onPressed: () => context.push(RoutePaths.history),
                  child: const Text('History'),
                ),
              ),
              const SizedBox(height: 10),
              assigned.when(
                data: (List<RiderAssignedOrder> list) {
                  if (list.isEmpty) {
                    return const RiderEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No assigned orders',
                      subtitle:
                          'Accepted deliveries appear here. Offers pop up while you\'re online.',
                    );
                  }
                  return Column(
                    children: list.map((RiderAssignedOrder o) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RiderLargeCard(
                          onTap: () => context.push(
                            '${RoutePaths.orderDetail}/${o.id}',
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              o.storeName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${o.referenceForDisplay}\n${o.status} · ${LkrFormat.money(o.totalLkr)}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => Text(
                  'Orders: $e',
                  style: TextStyle(color: cs.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
