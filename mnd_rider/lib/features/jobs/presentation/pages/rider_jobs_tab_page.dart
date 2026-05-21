import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/widgets/rider_empty_state.dart';
import 'package:mnd_rider/core/widgets/rider_large_card.dart';
import 'package:mnd_rider/core/widgets/rider_online_toggle_card.dart';
import 'package:mnd_rider/core/widgets/rider_section_title.dart';
import 'package:mnd_rider/core/widgets/rider_stat_tile.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/earnings/presentation/providers/rider_earnings_from_orders_provider.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/orders/presentation/providers/rider_active_order_provider.dart';

class RiderJobsTabPage extends ConsumerWidget {
  const RiderJobsTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RiderDashboardState dash = ref.watch(riderDashboardProvider);
    final RiderDashboardNotifier ctrl =
        ref.read(riderDashboardProvider.notifier);
    final RiderEarningsSummary earnings =
        ref.watch(riderEarningsSummaryProvider);
    final AsyncValue<List<RiderAssignedOrder>> assigned =
        ref.watch(assignedRiderOrdersProvider);
    final AsyncValue<List<RiderOrderDetail>> openJobs =
        ref.watch(openRiderJobsProvider);
    final String? activeId = ref.watch(activeRiderOrderIdProvider);

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(assignedRiderOrdersProvider);
          ref.invalidate(openRiderJobsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            8,
            AppSpacing.screenPadding,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const RiderSectionTitle('Status'),
              const SizedBox(height: 10),
              RiderOnlineToggleCard(
                isOnline: dash.isOnline,
                onChanged: ctrl.setOnline,
              ),
              if (dash.isOnline) ...<Widget>[
                const SizedBox(height: 8),
                openJobs.when(
                  data: (List<RiderOrderDetail> jobs) => Text(
                    '${jobs.length} open ${jobs.length == 1 ? 'job' : 'jobs'} ready',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
              const SizedBox(height: AppSpacing.sectionGap),
              const RiderSectionTitle('Today'),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: RiderStatTile(
                      label: 'Earned',
                      value: LkrFormat.moneyDecimal(earnings.todayNet),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RiderStatTile(
                      label: 'Trips',
                      value: '${earnings.tripsToday}',
                      icon: Icons.local_shipping_outlined,
                      accent: AppColors.onlineGreen,
                    ),
                  ),
                ],
              ),
              if (activeId != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sectionGap),
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
              ],
              const SizedBox(height: AppSpacing.sectionGap),
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
                      icon: Icons.delivery_dining_outlined,
                      title: 'No assigned orders',
                      subtitle:
                          'Go online to receive offers when vendors mark orders ready.',
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
