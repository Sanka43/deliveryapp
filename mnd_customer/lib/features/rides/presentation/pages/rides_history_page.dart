import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/money_format.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_gradient_badge.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_empty_state.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_trip.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/rides_providers.dart';
import 'package:mnd_delivery_app/features/rides/presentation/ride_status_style.dart';

class RidesHistoryPage extends ConsumerWidget {
  const RidesHistoryPage({super.key});

  static String? _formatDate(DateTime? d) {
    if (d == null) {
      return null;
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} · ${two(d.hour)}:${two(d.minute)}';
  }

  static String _truncateRoute(String pickup, String dropoff) {
    String clip(String s) {
      final String t = s.trim();
      if (t.length <= 42) {
        return t;
      }
      return '${t.substring(0, 40)}…';
    }

    return '${clip(pickup)} → ${clip(dropoff)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<User?> auth = ref.watch(authStateUserProvider);
    final AsyncValue<List<RideTrip>> trips = ref.watch(myRideTripsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ride history'),
      ),
      body: auth.when(
        data: (User? user) {
          if (user == null) {
            return MndEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in to see your rides',
              subtitle: 'Your ride history is saved to your account.',
              actionLabel: 'Sign in',
              onAction: () {
                ref.read(guestBrowsingProvider.notifier).state = false;
                ref.read(postAuthRedirectProvider.notifier).state =
                    AppRoutes.customerRidesHistory;
                context.go(AppRoutes.login);
              },
            );
          }
          return trips.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  userFacingError(
                    e,
                    fallback: 'Could not load rides. Please try again.',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            data: (List<RideTrip> list) {
              if (list.isEmpty) {
                return MndEmptyState(
                  icon: Icons.directions_car_outlined,
                  title: 'No rides yet',
                  subtitle: 'Book a ride to see it here.',
                  actionLabel: 'Book a ride',
                  onAction: () => context.go(AppRoutes.customerRides),
                );
              }

              final List<RideTrip> active = list
                  .where((RideTrip t) => t.isActive)
                  .toList();
              final List<RideTrip> past = list
                  .where((RideTrip t) => !t.isActive)
                  .toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                children: <Widget>[
                  MndSectionHeader(
                    title: 'Active (${active.length})',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (active.isEmpty)
                    const _EmptyHint(text: 'No active rides right now.')
                  else
                    ...active.map(
                      (RideTrip t) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _RideCard(
                          trip: t,
                          formatDate: _formatDate,
                          truncateRoute: _truncateRoute,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  MndSectionHeader(
                    title: 'Past (${past.length})',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (past.isEmpty)
                    const _EmptyHint(text: 'No past rides yet.')
                  else
                    ...past.map(
                      (RideTrip t) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _RideCard(
                          trip: t,
                          formatDate: _formatDate,
                          truncateRoute: _truncateRoute,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Could not verify sign-in.\n$err',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.trip,
    required this.formatDate,
    required this.truncateRoute,
  });

  final RideTrip trip;
  final String? Function(DateTime?) formatDate;
  final String Function(String, String) truncateRoute;

  void _onTap(BuildContext context) {
    if (trip.status == RideConstants.statusSearching ||
        trip.status == RideConstants.statusDraftPayment) {
      context.push(AppRoutes.customerRideTrip(trip.id));
      return;
    }
    if (trip.isTrackable || trip.needsOnlinePayment) {
      context.push(AppRoutes.customerRideTracking(trip.id));
      return;
    }
    showMndSnackBar(context, '${RideStatusStyle.labelFor(trip.status)} · '
          '${MoneyFormat.lkr(trip.estimatedFareLkr, showDecimals: false)}');
  }

  @override
  Widget build(BuildContext context) {
    final String vehicleLabel =
        trip.vehicle?.label ?? trip.vehicleType;
    final String? dateLabel = formatDate(trip.createdAt);

    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusSm,
      onTap: () => _onTap(context),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  vehicleLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              MndGradientBadge(
                label: RideStatusStyle.labelFor(trip.status),
                style: RideStatusStyle.badgeStyleFor(trip.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            MoneyFormat.lkr(trip.estimatedFareLkr, showDecimals: false),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (dateLabel != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              dateLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            truncateRoute(trip.pickup.label, trip.dropoff.label),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (trip.isTrackable ||
              trip.needsOnlinePayment ||
              trip.status == RideConstants.statusSearching ||
              trip.status == RideConstants.statusDraftPayment) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _onTap(context),
                icon: Icon(
                  trip.needsOnlinePayment
                      ? Icons.payment_rounded
                      : trip.isTrackable
                          ? Icons.map_outlined
                          : Icons.search_rounded,
                  size: 18,
                ),
                label: Text(
                  trip.needsOnlinePayment
                      ? 'Pay now'
                      : trip.isTrackable
                          ? 'Track'
                          : 'Continue',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
