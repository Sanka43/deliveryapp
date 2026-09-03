import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/widgets/rider_drive_sheet.dart';
import 'package:mnd_rider/core/widgets/rider_primary_cta.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';

/// Offer sheet for a passenger ride — same shell as [RiderOrderRequestCard]
/// (drive sheet, countdown, Reject/Accept), but a route-first body: circular
/// countdown ring, fare hero, vehicle/distance chip, and a connected
/// pickup-to-dropoff line instead of two disjoint dots.
class RiderRideRequestCard extends StatelessWidget {
  const RiderRideRequestCard({
    super.key,
    required this.trip,
    required this.secondsRemaining,
    required this.totalSeconds,
    required this.onAccept,
    required this.onReject,
    this.accepting = false,
  });

  final RiderPassengerTrip trip;
  final int secondsRemaining;
  final int totalSeconds;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool accepting;

  static IconData _vehicleIcon(String vehicleType) {
    switch (vehicleType.trim().toLowerCase()) {
      case 'wheel':
        return Icons.electric_rickshaw_outlined;
      case 'car':
        return Icons.directions_car_outlined;
      case 'bike':
      default:
        return Icons.two_wheeler_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final double progress = totalSeconds <= 0
        ? 0
        : (secondsRemaining / totalSeconds).clamp(0.0, 1.0);
    final bool urgent = secondsRemaining <= 10;

    return RiderDriveSheet(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.sports_motorsports_rounded,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'New ride offer',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _CountdownRing(
                secondsRemaining: secondsRemaining,
                progress: progress,
                urgent: urgent,
                cs: cs,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: <Widget>[
                Text(
                  LkrFormat.money(trip.estimatedFareLkr),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trip.isOnlinePayment ? 'Paid online' : 'Cash on trip',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        _vehicleIcon(trip.vehicleType),
                        size: 15,
                        color: cs.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        trip.vehicleType.toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '·',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                      Icon(
                        Icons.route_rounded,
                        size: 15,
                        color: cs.onSurface,
                      ),
                      const SizedBox(width: 6),
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
          ),
          const SizedBox(height: 20),
          _RouteLine(
            pickup: trip.pickupLabel,
            dropoff: trip.dropoffLabel,
            cs: cs,
            theme: theme,
          ),
          if ((trip.driverNote ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              trip.driverNote!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: RiderDangerCta(
                  label: 'Reject',
                  height: AppSpacing.ctaHeight,
                  onPressed: accepting ? null : onReject,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: RiderPrimaryCta(
                  label: 'Accept',
                  icon: Icons.check_rounded,
                  busy: accepting,
                  height: AppSpacing.ctaHeightLg,
                  onPressed: accepting ? null : onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    required this.secondsRemaining,
    required this.progress,
    required this.urgent,
    required this.cs,
    required this.theme,
  });

  final int secondsRemaining;
  final double progress;
  final bool urgent;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color ringColor = urgent ? AppColors.warningAmber : AppColors.primaryBlue;
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(ringColor),
            ),
          ),
          Text(
            '$secondsRemaining',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pickup and drop-off, connected by a single line so they read as one
/// route rather than two disjoint rows.
class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.pickup,
    required this.dropoff,
    required this.cs,
    required this.theme,
  });

  final String pickup;
  final String dropoff;
  final ColorScheme cs;
  final ThemeData theme;

  // Dot slot width and the line's horizontal offset within it — kept as
  // constants so the line and dots stay visually centered on each other.
  static const double _dotSlotWidth = 20;
  static const double _dotSize = 9;
  static const double _lineWidth = 1.5;
  static const double _lineLeft = (_dotSlotWidth - _lineWidth) / 2;

  @override
  Widget build(BuildContext context) {
    // A Stack + Positioned line (filling between fixed top/bottom insets)
    // instead of IntrinsicHeight + Expanded: IntrinsicHeight needs an extra
    // dry-layout pass to measure the address Text widgets' wrapped height,
    // and that pass is wrong on the very first frame (only self-corrects on
    // the next rebuild, e.g. the countdown timer's 1s tick) — visible as the
    // line rendering short/misaligned for a moment before "snapping" into
    // place. Positioned with top/bottom insets needs no such pre-measurement,
    // so it's correct from the first frame.
    return Stack(
      children: <Widget>[
        Positioned(
          left: _lineLeft,
          top: 5 + _dotSize + 4,
          bottom: 5 + _dotSize + 4,
          child: Container(width: _lineWidth, color: cs.outlineVariant),
        ),
        // Dropoff dot anchored from the bottom (mirrors the pickup dot's
        // top-anchoring) so it needs no intrinsic pre-measurement either.
        Positioned(
          left: (_dotSlotWidth - _dotSize) / 2,
          bottom: 5,
          child: Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: AppColors.dropoffRed,
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: _dotSlotWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.pickupGreen,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                _RouteLabel(
                  label: 'PICKUP',
                  address: pickup,
                  color: AppColors.pickupGreen,
                  theme: theme,
                  cs: cs,
                ),
                const SizedBox(height: 16),
                _RouteLabel(
                  label: 'DROPOFF',
                  address: dropoff,
                  color: AppColors.dropoffRed,
                  theme: theme,
                  cs: cs,
                ),
              ],
            ),
          ),
        ],
      ),
      ],
    );
  }
}

class _RouteLabel extends StatelessWidget {
  const _RouteLabel({
    required this.label,
    required this.address,
    required this.color,
    required this.theme,
    required this.cs,
  });

  final String label;
  final String address;
  final Color color;
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
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
    );
  }
}
