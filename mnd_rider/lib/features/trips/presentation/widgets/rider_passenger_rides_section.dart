import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/widgets/rider_primary_cta.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/orders/presentation/providers/rider_active_order_provider.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';

/// Passenger ride offers + active trip progress controls.
class RiderPassengerRidesSection extends ConsumerWidget {
  const RiderPassengerRidesSection({super.key});

  static String _humanStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'searching':
        return 'Looking for rider';
      case 'accepted':
        return 'Head to pickup';
      case 'arrived':
        return 'Arrived at pickup';
      case 'in_progress':
        return 'Trip in progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  void _openRide(BuildContext context, RiderPassengerTrip t) {
    context.push('${RoutePaths.ride}/${t.id}', extra: t);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RiderPassengerTrip>> open =
        ref.watch(matchedOpenPassengerTripsProvider);
    final AsyncValue<List<RiderPassengerTrip>> active =
        ref.watch(myActivePassengerTripsProvider);
    final List<RiderPassengerTrip> recentlyCompleted = ref
            .watch(myRecentlyCompletedPassengerTripsProvider)
            .valueOrNull ??
        const <RiderPassengerTrip>[];
    final RiderProfile? profile =
        ref.watch(riderProfileStreamProvider).valueOrNull;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final List<RiderPassengerTrip> activeList =
        active.valueOrNull ?? const <RiderPassengerTrip>[];
    final List<RiderPassengerTrip> openList =
        open.valueOrNull ?? const <RiderPassengerTrip>[];
    final bool loading = active.isLoading || open.isLoading;

    // Rider opted out of new ride offers and has nothing active or recently
    // finished — keep the Jobs tab clean instead of showing an always-empty
    // section.
    if (profile != null &&
        !profile.acceptsPassengerRides &&
        activeList.isEmpty &&
        recentlyCompleted.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Passenger rides',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        if (loading && activeList.isEmpty && openList.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (active.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${active.error}'),
          ),
        ...activeList.map((RiderPassengerTrip t) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RideTile(
              title: '${t.pickupLabel}  →  ${t.dropoffLabel}',
              subtitle: '${t.vehicleType.toUpperCase()} · '
                  '${_humanStatus(t.status)} · '
                  '${LkrFormat.money(t.estimatedFareLkr)}',
              onTap: () => _openRide(context, t),
            ),
          );
        }),
        // A ride that just finished (or got cancelled) stays visible here
        // briefly instead of disappearing the instant it leaves the active
        // list above — the same confirmation "My deliveries" already gives
        // for a completed order. Cash trips whose payment wasn't confirmed
        // yet still need a way back to that step, so this stays tappable.
        ...recentlyCompleted.map((RiderPassengerTrip t) {
          final bool needsCashConfirm =
              !t.isOnlinePayment && t.status.toLowerCase() == 'completed' && !t.isPaid;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RideTile(
              title: '${t.pickupLabel}  →  ${t.dropoffLabel}',
              subtitle: '${t.vehicleType.toUpperCase()} · '
                  '${_humanStatus(t.status)} · '
                  '${LkrFormat.money(t.estimatedFareLkr)}'
                  '${needsCashConfirm ? ' · Confirm payment' : ''}',
              accentColor: needsCashConfirm ? AppColors.warningAmber : null,
              onTap: () => _openRide(context, t),
            ),
          );
        }),
        if (open.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${open.error}'),
          ),
        if (!loading && openList.isEmpty && activeList.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              'No passenger rides for your vehicle right now.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else ...<Widget>[
          ...openList.map((RiderPassengerTrip t) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RideCard(
                title:
                    '${t.vehicleType.toUpperCase()} · ${t.distanceKm.toStringAsFixed(1)} km',
                pickup: t.pickupLabel,
                dropoff: t.dropoffLabel,
                meta: LkrFormat.money(t.estimatedFareLkr) +
                    (t.isOnlinePayment ? ' · Paid online' : ' · Cash') +
                    ((t.driverNote ?? '').isNotEmpty
                        ? ' · ${t.driverNote}'
                        : ''),
                action: RiderPrimaryCta(
                  label: ref.watch(riderIsBusyProvider)
                      ? 'Busy on another job'
                      : 'Accept ride',
                  height: AppSpacing.ctaHeight,
                  color: AppColors.primaryBlue,
                  onPressed: ref.watch(riderIsBusyProvider)
                      ? null
                      : () async {
                          final String? err = await ref
                              .read(riderTripsRepositoryProvider)
                              .claimTrip(t.id);
                          if (!context.mounted) {
                            return;
                          }
                          if (err != null) {
                            showRiderSnackBar(context, err);
                            return;
                          }
                          showRiderSnackBar(context, 'Ride accepted.');
                          context.push(
                            '${RoutePaths.ride}/${t.id}',
                            extra: t,
                          );
                        },
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.sectionGap),
        ],
      ],
    );
  }
}

/// Compact row tile matching the "My deliveries" list style — used for
/// rides that are already active or finished, where tapping just opens
/// the trip. Open (unclaimed) ride offers keep the fuller [_RideCard]
/// below since accepting is a distinct action, not just a view.
class _RideTile extends StatelessWidget {
  const _RideTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accentColor,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accentColor;

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
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: accentColor ?? cs.onSurfaceVariant,
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

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.title,
    required this.pickup,
    required this.dropoff,
    required this.meta,
    required this.action,
  });

  final String title;
  final String pickup;
  final String dropoff;
  final String meta;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

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
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$pickup  →  $dropoff',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
