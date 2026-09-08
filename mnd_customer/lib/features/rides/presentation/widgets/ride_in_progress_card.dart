import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/utils/money_format.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_trip.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/presentation/ride_status_style.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_theme.dart';

/// Floating status card shown over the map while a ride is being searched,
/// matched, or driven — everything before `completed`. Replaces a flat stack
/// of plain-white text with the same "receipt" look [RideCompletedCard]
/// already uses on this same page: an icon badge, a metrics row of
/// translucent tiles, and a current-destination row, so the two states read
/// as one consistent design instead of the earlier one looking unfinished
/// next to the other.
class RideInProgressCard extends StatelessWidget {
  const RideInProgressCard({
    super.key,
    required this.trip,
    required this.etaText,
  });

  final RideTrip trip;
  final String? etaText;

  ({IconData icon, Color color}) get _statusVisual => switch (trip.status) {
        RideConstants.statusArrived => (
            icon: Icons.pin_drop_rounded,
            color: const Color(RidesColors.pickupGreen),
          ),
        RideConstants.statusInProgress => (
            icon: Icons.navigation_rounded,
            color: RidesColors.accentBlue,
          ),
        RideConstants.statusAccepted => (
            icon: Icons.directions_car_filled_rounded,
            color: RidesColors.accentBlue,
          ),
        _ => (
            icon: Icons.search_rounded,
            color: const Color(RidesColors.stopAmber),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ({IconData icon, Color color}) visual = _statusVisual;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(RidesSheet.outerMargin),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(RidesColors.sheetNavy),
        borderRadius: BorderRadius.circular(RidesSheet.cardRadius + 4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(visual.icon, color: visual.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      RideStatusStyle.labelFor(trip.status),
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      etaText != null ? 'ETA $etaText' : 'Getting the latest update…',
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(RidesColors.mutedOnNavy),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricTile(
                  icon: Icons.local_taxi_rounded,
                  label: 'Vehicle',
                  value: trip.vehicle?.label ?? trip.vehicleType,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.payments_rounded,
                  label: 'Fare',
                  value: MoneyFormat.lkr(
                    trip.estimatedFareLkr,
                    showDecimals: false,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.route_rounded,
                  label: 'Distance',
                  value: '${trip.distanceKm.toStringAsFixed(1)} km',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(RidesSheet.buttonRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.place_rounded,
                  size: 18,
                  color: visual.color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.currentLegLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
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
