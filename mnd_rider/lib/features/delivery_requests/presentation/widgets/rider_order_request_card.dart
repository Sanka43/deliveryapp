import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/widgets/rider_drive_sheet.dart';
import 'package:mnd_rider/core/widgets/rider_primary_cta.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';

/// Offer sheet — fare first, Accept-dominant, glanceable while riding.
class RiderOrderRequestCard extends StatelessWidget {
  const RiderOrderRequestCard({
    super.key,
    required this.request,
    required this.secondsRemaining,
    required this.totalSeconds,
    required this.onAccept,
    required this.onReject,
    this.accepting = false,
  });

  final RiderDeliveryRequest request;
  final int secondsRemaining;
  final int totalSeconds;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool accepting;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final double progress = totalSeconds <= 0
        ? 0
        : (secondsRemaining / totalSeconds).clamp(0.0, 1.0);
    final bool urgent = secondsRemaining <= 10;

    return RiderDriveSheet(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'NEW OFFER',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${secondsRemaining}s',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: urgent ? AppColors.warningAmber : cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: cs.surfaceContainerLow,
              color: urgent ? AppColors.warningAmber : AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            request.feeAfterTrip
                ? 'Fee after trip'
                : LkrFormat.money(request.estimatedEarningsLkr),
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: 0,
              height: 1,
              fontSize: request.feeAfterTrip ? 28 : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            request.feeAfterTrip
                ? (request.productsPaid
                    ? 'Collect delivery only · paid products'
                    : 'Collect products + delivery')
                : 'Estimated earnings',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.near_me_rounded,
                  size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                request.distanceToPickupLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '·',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
              Icon(Icons.route_rounded,
                  size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                request.routeKmLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _LegLine(
            color: AppColors.pickupGreen,
            label: 'Pickup',
            address: request.vendorName.isNotEmpty
                ? '${request.vendorName} · ${request.pickupAddress}'
                : request.pickupAddress,
          ),
          const SizedBox(height: 10),
          _LegLine(
            color: AppColors.dropoffRed,
            label: 'Dropoff',
            address: request.customerAddress,
          ),
          if (request.itemsSummary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              request.itemsSummary,
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

class _LegLine extends StatelessWidget {
  const _LegLine({
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
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 12),
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
