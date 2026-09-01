import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/core/widgets/rider_error_state.dart';
import 'package:mnd_rider/core/widgets/rider_skeleton.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/earnings/presentation/widgets/rider_cash_hold_banner.dart';
import 'package:mnd_rider/features/jobs/presentation/widgets/rider_open_jobs_section.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/orders/presentation/providers/rider_active_order_provider.dart';
import 'package:mnd_rider/features/trips/presentation/widgets/rider_passenger_rides_section.dart';
import 'package:mnd_rider/features/shell/presentation/widgets/rider_floating_nav_bar.dart';

class RiderJobsTabPage extends ConsumerWidget {
  const RiderJobsTabPage({super.key});

  static String humanStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'ready_for_pickup':
      case 'ready':
        return 'Ready for pickup';
      case 'picked_up':
        return 'Picked up';
      case 'on_the_way':
      case 'out_for_delivery':
        return 'On the way';
      case 'delivered':
        return 'Delivered';
      case 'accepted':
        return 'Accepted';
      case 'assigned':
        return 'Assigned';
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RiderDashboardState dash = ref.watch(riderDashboardProvider);
    final RiderDashboardNotifier ctrl =
        ref.read(riderDashboardProvider.notifier);
    final bool approved = ref.watch(riderIsApprovedToDriveProvider);
    final AsyncValue<List<RiderAssignedOrder>> assigned =
        ref.watch(assignedRiderOrdersProvider);
    final String? activeId = ref.watch(activeRiderOrderIdProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppColors.primaryBlue,
        onRefresh: () async {
          ref.invalidate(assignedRiderOrdersProvider);
          ref.invalidate(openRiderJobsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              floating: false,
              automaticallyImplyLeading: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              titleSpacing: AppSpacing.screenPadding,
              title: Text(
                'Jobs',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: cs.onSurface,
                ),
              ),
              actions: <Widget>[
                if (approved)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _OnlineChip(
                      isOnline: dash.isOnline,
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        final String? err =
                            await ctrl.setOnline(!dash.isOnline);
                        if (context.mounted && err != null) {
                          showRiderSnackBar(context, err);
                        }
                      },
                    ),
                  ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                4,
                AppSpacing.screenPadding,
                16 + riderFloatingNavTotalHeight(context),
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    if (!approved) ...<Widget>[
                      const _NoticeBanner(
                        tone: AppColors.warningAmber,
                        title: 'Approval pending',
                        body:
                            'An admin must approve your profile before you can take jobs.',
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (activeId != null) ...<Widget>[
                      ref.watch(riderOrderDetailProvider(activeId)).when(
                            data: (RiderOrderDetail? order) {
                              if (order == null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _ActiveTripBanner(
                                  storeName: order.storeName,
                                  status: humanStatus(order.status),
                                  reference: order.referenceForDisplay,
                                  onContinue: () => context.push(
                                    '${RoutePaths.trip}/${order.id}',
                                    extra: order,
                                  ),
                                ),
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                    ],
                    const RiderCashHoldBanner(
                      margin: EdgeInsets.only(bottom: 16),
                    ),
                    if (approved) ...<Widget>[
                      _SectionLabel(
                        title: 'Available',
                        trailing: dash.isOnline ? null : 'Offline',
                      ),
                      const SizedBox(height: 10),
                      if (!dash.isOnline)
                        _OfflinePrompt(
                          onGoOnline: () async {
                            HapticFeedback.mediumImpact();
                            final String? err = await ctrl.setOnline(true);
                            if (context.mounted && err != null) {
                              showRiderSnackBar(context, err);
                            }
                          },
                        )
                      else
                        const RiderOpenJobsSection(),
                      const SizedBox(height: 22),
                      const RiderPassengerRidesSection(),
                    ],
                    _SectionLabel(
                      title: 'My deliveries',
                      trailingAction: TextButton(
                        onPressed: () => context.push(RoutePaths.history),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('History'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    assigned.when(
                      data: (List<RiderAssignedOrder> list) {
                        if (list.isEmpty) {
                          return _EmptyDeliveries(
                            isOnline: dash.isOnline,
                            approved: approved,
                          );
                        }
                        return Column(
                          children: list.map((RiderAssignedOrder o) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _AssignedOrderTile(
                                storeName: o.storeName,
                                status: humanStatus(o.status),
                                amount: LkrFormat.money(o.totalLkr),
                                onTap: () => context.push(
                                  '${RoutePaths.orderDetail}/${o.id}',
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const RiderSkeletonList(
                        count: 2,
                        showLeading: false,
                        padding: EdgeInsets.zero,
                      ),
                      error: (Object e, _) {
                        if (!approved || isFirestorePermissionDenied(e)) {
                          return _EmptyDeliveries(
                            isOnline: dash.isOnline,
                            approved: approved,
                          );
                        }
                        return RiderErrorState(
                          message: userFacingError(
                            e,
                            fallback:
                                'Could not load deliveries. Pull to refresh.',
                          ),
                          onRetry: () =>
                              ref.invalidate(assignedRiderOrdersProvider),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineChip extends StatelessWidget {
  const _OnlineChip({required this.isOnline, required this.onTap});

  final bool isOnline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tone =
        isOnline ? AppColors.onlineGreen : AppColors.offlineGrey;

    return Material(
      color: tone.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    this.trailing,
    this.trailingAction,
  });

  final String title;
  final String? trailing;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: cs.onSurface,
                ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ?trailingAction,
      ],
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.tone,
    required this.title,
    required this.body,
  });

  final Color tone;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _OfflinePrompt extends StatelessWidget {
  const _OfflinePrompt({required this.onGoOnline});

  final VoidCallback onGoOnline;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onGoOnline,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Go online to see open jobs',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nearby delivery offers appear here when you\'re available.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.onlineGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Go online',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveTripBanner extends StatelessWidget {
  const _ActiveTripBanner({
    required this.storeName,
    required this.status,
    required this.reference,
    required this.onContinue,
  });

  final String storeName;
  final String status;
  final String reference;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryBlue,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onContinue,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Active delivery',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      storeName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$status${reference != '—' ? ' · $reference' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Continue',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignedOrderTile extends StatelessWidget {
  const _AssignedOrderTile({
    required this.storeName,
    required this.status,
    required this.amount,
    required this.onTap,
  });

  final String storeName;
  final String status;
  final String amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      storeName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$status · $amount',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDeliveries extends StatelessWidget {
  const _EmptyDeliveries({
    required this.isOnline,
    required this.approved,
  });

  final bool isOnline;
  final bool approved;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String body = !approved
        ? 'Assigned deliveries will show here after approval.'
        : isOnline
            ? 'Accepted jobs will appear here while you deliver.'
            : 'Go online and claim a job to start delivering.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        body,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
      ),
    );
  }
}
