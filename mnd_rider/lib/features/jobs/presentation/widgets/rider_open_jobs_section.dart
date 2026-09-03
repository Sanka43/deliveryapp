import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/core/widgets/rider_primary_cta.dart';
import 'package:mnd_rider/core/widgets/rider_skeleton.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/rider_delivery_requests_provider.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/rider_order_accept_provider.dart';
import 'package:mnd_rider/features/orders/presentation/providers/rider_active_order_provider.dart';

/// Manual claim list for the Jobs tab (visible only while online).
class RiderOpenJobsSection extends ConsumerStatefulWidget {
  const RiderOpenJobsSection({super.key});

  @override
  ConsumerState<RiderOpenJobsSection> createState() =>
      _RiderOpenJobsSectionState();
}

class _RiderOpenJobsSectionState extends ConsumerState<RiderOpenJobsSection> {
  String? _acceptingId;

  Future<void> _accept(RiderDeliveryRequest request) async {
    if (_acceptingId != null) {
      return;
    }
    setState(() => _acceptingId = request.orderId);

    final RiderOrderAcceptResult result = await ref.read(
      riderOrderAcceptProvider,
    )(request);

    if (!mounted) {
      return;
    }
    setState(() => _acceptingId = null);

    if (!result.isSuccess) {
      showRiderSnackBar(context, result.error ?? 'Could not accept order');
      return;
    }
    final String tripId = result.tripOrderId ?? request.orderId;
    if (tripId.isNotEmpty) {
      context.push('${RoutePaths.trip}/$tripId', extra: result.order);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<RiderDeliveryRequest>> asyncJobs = ref.watch(
      openDeliveryRequestsProvider,
    );
    final bool hasActiveDelivery = ref.watch(riderIsBusyProvider);

    return asyncJobs.when(
      loading: () => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _OpenJobCardSkeleton(),
          ),
          _OpenJobCardSkeleton(),
        ],
      ),
      error: (Object e, _) => _EmptyAvailable(
        title: 'Couldn\'t load jobs',
        body: userFacingError(e),
        onRetry: () => ref.invalidate(rawOpenDeliveryRequestsProvider),
      ),
      data: (List<RiderDeliveryRequest> jobs) {
        if (jobs.isEmpty) {
          return const _EmptyAvailable(
            title: 'No open jobs nearby',
            body: 'Stay online — new delivery offers will show up here.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: jobs.map((RiderDeliveryRequest job) {
            final bool acceptingThis = _acceptingId == job.orderId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OpenJobCard(
                job: job,
                busy: acceptingThis,
                blocked: hasActiveDelivery || _acceptingId != null,
                blockedReason: hasActiveDelivery
                    ? 'Finish current delivery first'
                    : null,
                onAccept: () => _accept(job),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _EmptyAvailable extends StatelessWidget {
  const _EmptyAvailable({
    required this.title,
    required this.body,
    this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Loading placeholder matching [_OpenJobCard]'s shape so the list doesn't
/// jump when real cards replace it.
class _OpenJobCardSkeleton extends StatelessWidget {
  const _OpenJobCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    RiderSkeletonBox(width: 140, height: 18),
                    SizedBox(height: 8),
                    RiderSkeletonBox(width: 100, height: 12),
                  ],
                ),
              ),
              SizedBox(width: 10),
              RiderSkeletonBox(width: 70, height: 22),
            ],
          ),
          SizedBox(height: 14),
          RiderSkeletonBox(
            width: double.infinity,
            height: 64,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          SizedBox(height: 14),
          RiderSkeletonBox(
            width: double.infinity,
            height: AppSpacing.ctaHeight,
            borderRadius: BorderRadius.all(
              Radius.circular(AppSpacing.buttonRadius),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenJobCard extends StatelessWidget {
  const _OpenJobCard({
    required this.job,
    required this.busy,
    required this.blocked,
    required this.onAccept,
    this.blockedReason,
  });

  final RiderDeliveryRequest job;
  final bool busy;
  final bool blocked;
  final String? blockedReason;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String payout = job.feeAfterTrip
        ? 'Fee after trip'
        : LkrFormat.money(job.estimatedEarningsLkr);
    final String acceptLabel = job.feeAfterTrip
        ? (blockedReason ?? 'Accept · fee after trip')
        : (blockedReason ?? 'Accept · $payout');

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        job.vendorName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: 0,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${job.deliveryType.label} · ${job.distanceToPickupLabel} to pickup'
                        '${job.productsPaid ? ' · Products paid' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    payout,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onlineGreen,
                      letterSpacing: 0,
                      height: 1.1,
                      fontSize: job.feeAfterTrip ? 14 : 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _RouteStrip(
              pickup: job.pickupAddress,
              dropoff: job.customerAddress,
              routeLabel: job.routeKmLabel,
            ),
            if (job.itemsSummary.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                job.itemsSummary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            RiderPrimaryCta(
              label: acceptLabel,
              height: AppSpacing.ctaHeight,
              color: AppColors.primaryBlue,
              busy: busy,
              onPressed: blocked ? null : onAccept,
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStrip extends StatelessWidget {
  const _RouteStrip({
    required this.pickup,
    required this.dropoff,
    required this.routeLabel,
  });

  final String pickup;
  final String dropoff;
  final String routeLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.pickupGreen,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 1.5,
                height: 22,
                margin: const EdgeInsets.symmetric(vertical: 3),
                color: cs.outlineVariant,
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.dropoffRed,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  dropoff,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            routeLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
