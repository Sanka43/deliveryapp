import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/utils/money_format.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/rides/data/rides_repository.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_trip.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_theme.dart';

/// End-of-ride summary shown over the map once a trip is `completed`.
///
/// The live-tracking sheet used to keep showing its in-progress layout after
/// the ride ended — a stale ETA, one cramped "Bike · LKR 403 · 4.2 km" line
/// and only the *current leg* address, so the customer never saw where the
/// ride actually started and finished. This lays the trip out as a receipt
/// instead: full route, distance, vehicle and fare each with their own label.
class RideCompletedCard extends StatelessWidget {
  const RideCompletedCard({
    super.key,
    required this.trip,
    required this.payingOnline,
    required this.onPayOnline,
    required this.onDone,
  });

  final RideTrip trip;

  /// True while a PayHere checkout is being created — swaps the pay button
  /// for a spinner and blocks a second tap.
  final bool payingOnline;
  final VoidCallback onPayOnline;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool needsOnlinePay = trip.needsOnlinePayment;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(RidesSheet.outerMargin),
      decoration: BoxDecoration(
        color: const Color(RidesColors.sheetNavy),
        borderRadius: BorderRadius.circular(20),
      ),
      // A ride with two stops on small phones would otherwise push the
      // buttons off-screen. Only the route list scrolls; fare, payment
      // state and the actions stay pinned below it, so the numbers the
      // customer actually came for are never the part that scrolls away.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _header(textTheme),
                    const SizedBox(height: 14),
                    _RouteSummary(trip: trip),
                    const SizedBox(height: 10),
                    _metrics(textTheme),
                    if (trip.effectiveRiderId != null) ...<Widget>[
                      const SizedBox(height: 10),
                      _RiderRatingSection(trip: trip),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _fareRow(textTheme),
                  const SizedBox(height: 10),
                  _PaymentStatusChip(trip: trip),
                  const SizedBox(height: 12),
                  if (needsOnlinePay) ...<Widget>[
                    SizedBox(
                      width: double.infinity,
                      height: RidesSheet.primaryButtonHeight,
                      child: FilledButton(
                        onPressed: payingOnline ? null : onPayOnline,
                        style: FilledButton.styleFrom(
                          backgroundColor: RidesColors.accentBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              RidesSheet.buttonRadius,
                            ),
                          ),
                        ),
                        child: payingOnline
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Pay ${MoneyFormat.lkr(trip.estimatedFareLkr, showDecimals: false)} now',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: RidesSheet.primaryButtonHeight,
                    child: OutlinedButton(
                      onPressed: onDone,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            RidesSheet.buttonRadius,
                          ),
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(TextTheme textTheme) {
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(RidesColors.pickupGreen).withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF43D07C),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Ride completed',
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Here is your trip summary',
                style: textTheme.bodySmall?.copyWith(
                  color: const Color(RidesColors.mutedOnNavy),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metrics(TextTheme textTheme) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _MetricTile(
            icon: Icons.route_rounded,
            label: 'Distance',
            value: '${trip.distanceKm.toStringAsFixed(1)} km',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            icon: Icons.local_taxi_rounded,
            label: 'Vehicle',
            value: trip.vehicle?.label ?? trip.vehicleType,
          ),
        ),
        if (trip.stops.isNotEmpty) ...<Widget>[
          const SizedBox(width: 8),
          Expanded(
            child: _MetricTile(
              icon: Icons.flag_rounded,
              label: 'Stops',
              value: '${trip.stops.length}',
            ),
          ),
        ],
      ],
    );
  }

  Widget _fareRow(TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(RidesSheet.buttonRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Total fare',
                  style: textTheme.labelSmall?.copyWith(
                    color: const Color(RidesColors.mutedOnNavy),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.15,
                  ),
                ),
                Text(
                  // The method only — whether it actually settled is the
                  // status chip's job, so an unpaid PayHere ride can't read
                  // "Paid online" right above an amber "Payment pending".
                  trip.paymentMethod == RideConstants.paymentPayHere
                      ? 'Online payment'
                      : 'Cash to the driver',
                  style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          Text(
            MoneyFormat.lkr(trip.estimatedFareLkr, showDecimals: false),
            style: textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick-up → stops → drop-off, each with its own label and full address.
class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.trip});

  final RideTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(RidesSheet.buttonRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _RouteRow(
            label: 'Pick-up',
            color: const Color(RidesColors.pickupGreen),
            text: trip.pickup.label,
          ),
          for (int i = 0; i < trip.stops.length; i++) ...<Widget>[
            const _RouteConnector(),
            _RouteRow(
              label: 'Stop ${i + 1}',
              color: const Color(RidesColors.stopAmber),
              text: trip.stops[i].label,
            ),
          ],
          const _RouteConnector(),
          _RouteRow(
            label: 'Drop-off',
            color: const Color(RidesColors.dropoffRed),
            text: trip.dropoff.label,
          ),
        ],
      ),
    );
  }
}

class _RouteConnector extends StatelessWidget {
  const _RouteConnector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.5,
      height: 12,
      margin: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
      color: Colors.white24,
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.label,
    required this.color,
    required this.text,
  });

  final String label;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.15,
                ),
              ),
              Text(
                text.isEmpty ? 'Location unavailable' : text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Where the money stands: settled (green), or still owed / unconfirmed (amber).
class _PaymentStatusChip extends StatelessWidget {
  const _PaymentStatusChip({required this.trip});

  final RideTrip trip;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isPayHere = trip.paymentMethod == RideConstants.paymentPayHere;
    final bool settled = trip.paymentStatus == 'paid';

    final String text;
    if (isPayHere) {
      text = settled
          ? 'Paid online via PayHere'
          : 'Payment pending — pay online to settle this ride';
    } else {
      text = settled
          ? 'Paid in cash to the driver'
          : 'Waiting for the driver to confirm cash payment';
    }
    final Color tone =
        settled ? const Color(0xFF43D07C) : const Color(0xFFF2B23E);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          settled ? Icons.verified_rounded : Icons.schedule_rounded,
          size: 18,
          color: tone,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium?.copyWith(
              color: tone,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Lets the customer rate the rider once the ride is completed — submits or
/// shows a read-only "thanks" state once already rated.
class _RiderRatingSection extends ConsumerStatefulWidget {
  const _RiderRatingSection({required this.trip});

  final RideTrip trip;

  @override
  ConsumerState<_RiderRatingSection> createState() =>
      _RiderRatingSectionState();
}

class _RiderRatingSectionState extends ConsumerState<_RiderRatingSection> {
  int _stars = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars < 1 || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    final RideRatingResult result =
        await ref.read(ridesRepositoryProvider).submitRiderRatingForTrip(
              tripId: widget.trip.id,
              stars: _stars,
              comment: _commentController.text,
            );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (result.ok) {
      showMndSnackBar(
        context,
        'Thanks for rating your rider!',
        variant: MndSnackBarVariant.success,
      );
    } else {
      showMndSnackBar(
        context,
        result.message ?? 'Could not submit rating.',
        variant: MndSnackBarVariant.error,
      );
    }
  }

  BoxDecoration get _boxDecoration => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(RidesSheet.buttonRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      );

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final RideTrip trip = widget.trip;

    if (trip.riderRated) {
      final int stars = trip.riderRatingStars ?? 0;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: _boxDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Your rider rating',
              style: textTheme.labelSmall?.copyWith(
                color: const Color(RidesColors.mutedOnNavy),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.15,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                for (int i = 1; i <= 5; i++)
                  Icon(
                    i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 22,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _boxDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Rate your rider',
            style: textTheme.labelSmall?.copyWith(
              color: const Color(RidesColors.mutedOnNavy),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              for (int i = 1; i <= 5; i++)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  onPressed:
                      _submitting ? null : () => setState(() => _stars = i),
                  icon: Icon(
                    i <= _stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 30,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _commentController,
            enabled: !_submitting,
            maxLength: 500,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Optional comment',
              hintStyle: const TextStyle(color: Colors.white38),
              counterStyle: const TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_stars < 1 || _submitting) ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: RidesColors.accentBlue,
                foregroundColor: Colors.white,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit rating'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(RidesSheet.buttonRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: RidesSheet.actionIconSize, color: Colors.white70),
          const SizedBox(height: 6),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: const Color(RidesColors.mutedOnNavy),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
