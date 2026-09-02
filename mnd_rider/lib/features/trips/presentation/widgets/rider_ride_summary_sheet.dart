import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/widgets/rider_primary_cta.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';

/// Shown in place of the driving CTA once a ride's final leg completes —
/// a route/cost recap, plus an explicit "Payment received" confirmation for
/// cash trips (online trips are settled by the customer, not the rider).
class RiderRideSummarySheet extends StatefulWidget {
  const RiderRideSummarySheet({
    super.key,
    required this.trip,
    this.onConfirmCashPayment,
    this.onDone,
  });

  final RiderPassengerTrip trip;

  /// Returns an error message on failure, or null on success. Omit for a
  /// read-only recap (e.g. reopening an already-finished ride) — the
  /// "Payment received" action and "Done" button are dropped when this and
  /// [onDone] are both null.
  final Future<String?> Function()? onConfirmCashPayment;
  final VoidCallback? onDone;

  @override
  State<RiderRideSummarySheet> createState() => _RiderRideSummarySheetState();
}

class _RiderRideSummarySheetState extends State<RiderRideSummarySheet> {
  bool _confirming = false;
  String? _error;

  Future<void> _confirmPayment() async {
    final Future<String?> Function()? confirm = widget.onConfirmCashPayment;
    if (confirm == null) {
      return;
    }
    setState(() {
      _confirming = true;
      _error = null;
    });
    final String? err = await confirm();
    if (!mounted) {
      return;
    }
    setState(() {
      _confirming = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final RiderPassengerTrip trip = widget.trip;
    final bool cash = !trip.isOnlinePayment;
    final bool cashPaid = cash && trip.isPaid;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen, size: 26),
            const SizedBox(width: 10),
            Text(
              'Ride completed',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                LkrFormat.money(trip.estimatedFareLkr),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: 0,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.route_rounded, size: 15, color: cs.onSurface),
                  const SizedBox(width: 5),
                  Text(
                    '${trip.distanceKm.toStringAsFixed(1)} km',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _RouteRow(
          color: AppColors.pickupGreen,
          label: 'Pickup',
          address: trip.pickupLabel,
        ),
        const SizedBox(height: 10),
        _RouteRow(
          color: AppColors.dropoffRed,
          label: 'Dropoff',
          address: trip.dropoffLabel,
        ),
        const SizedBox(height: 18),
        if (cash) ...<Widget>[
          if (cashPaid)
            _PaymentConfirmedBanner(amountLkr: trip.estimatedFareLkr)
          else if (widget.onConfirmCashPayment != null) ...<Widget>[
            RiderPrimaryCta(
              label: 'Payment received',
              icon: Icons.payments_rounded,
              busy: _confirming,
              height: AppSpacing.ctaHeightLg,
              onPressed: _confirming ? null : _confirmPayment,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              ),
              child: Text(
                'Cash payment not confirmed yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ] else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            child: Text(
              'Customer pays online after the trip — no cash to collect.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (widget.onDone != null) ...<Widget>[
          const SizedBox(height: 10),
          SizedBox(
            height: AppSpacing.ctaHeight,
            child: OutlinedButton(
              onPressed: widget.onDone,
              child: const Text('Done'),
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentConfirmedBanner extends StatelessWidget {
  const _PaymentConfirmedBanner({required this.amountLkr});

  final int amountLkr;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.onlineGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(color: AppColors.onlineGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${LkrFormat.money(amountLkr)} cash payment confirmed',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onlineGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.color,
    required this.label,
    required this.address,
  });

  final Color color;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
