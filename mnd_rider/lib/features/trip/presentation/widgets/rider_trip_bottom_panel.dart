import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/widgets/rider_drive_sheet.dart';
import 'package:mnd_rider/core/widgets/rider_slide_to_confirm.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/trip/domain/rider_trip_phase.dart';
import 'package:mnd_rider/features/trip/presentation/providers/rider_trip_tracking_provider.dart';

/// Compact driving panel: giant ETA, one destination line, one primary CTA.
class RiderTripBottomPanel extends ConsumerWidget {
  const RiderTripBottomPanel({
    super.key,
    required this.order,
    required this.phase,
    required this.vendorPosition,
    required this.customerPosition,
    required this.pickupAddress,
    required this.busy,
    required this.onOrderPickedUp,
    required this.onDelivered,
    required this.onOpenMaps,
    this.onCallShop,
    this.liveTraveledKm,
    this.liveDeliveryFeeLkr,
    this.liveCollectLkr,
    this.showPrepaidNote = false,
  });

  final RiderOrderDetail order;
  final RiderTripPhase phase;
  final LatLng? vendorPosition;
  final LatLng? customerPosition;
  final String pickupAddress;
  final bool busy;

  /// Single vendor-leg action: records pickup and heads to the customer.
  final VoidCallback onOrderPickedUp;
  final VoidCallback onDelivered;
  final VoidCallback onOpenMaps;
  final VoidCallback? onCallShop;
  final double? liveTraveledKm;
  final int? liveDeliveryFeeLkr;
  final int? liveCollectLkr;

  /// True when the order was already paid online — nothing to collect.
  final bool showPrepaidNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool vendorLeg = phase.isVendorLeg;
    final LatLng? target = vendorLeg ? vendorPosition : customerPosition;
    final RiderTripEtaSnapshot eta = ref.watch(
      riderTripEtaProvider(
        RiderTripEtaInput(
          target: target,
          label: vendorLeg ? 'To store' : 'To customer',
        ),
      ),
    );
    final Color legColor = vendorLeg
        ? AppColors.pickupGreen
        : AppColors.dropoffRed;
    final String destinationTitle = vendorLeg ? order.storeName : 'Customer';
    final String destinationLine = vendorLeg
        ? pickupAddress
        : order.dropoffAddressSingleLine;

    return RiderDriveSheet(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _LegStepper(vendorLeg: vendorLeg, legColor: legColor),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      eta.durationText,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${eta.label} · ${eta.distanceText}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onCallShop != null) ...<Widget>[
                _OutlineIconButton(
                  icon: Icons.storefront_rounded,
                  tooltip: 'Call shop',
                  onPressed: busy ? null : onCallShop,
                ),
                const SizedBox(width: 10),
              ],
              _OutlineIconButton(
                icon: Icons.navigation_rounded,
                tooltip: vendorLeg ? 'Navigate to store' : 'Open Maps',
                onPressed: busy ? null : onOpenMaps,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: cs.outlineVariant),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      destinationTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destinationLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (order.referenceForDisplay != '—') ...<Widget>[
                const SizedBox(width: 12),
                Text(
                  order.referenceForDisplay,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
          if (liveDeliveryFeeLkr != null && liveCollectLkr != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: cs.outlineVariant),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Text(
                    liveTraveledKm != null
                        ? 'Trip ${liveTraveledKm!.toStringAsFixed(1)} km · '
                              'Delivery ${LkrFormat.money(liveDeliveryFeeLkr!)}'
                        : order.productsPaid
                        ? 'Delivery fee · products already paid'
                        : 'Delivery ${LkrFormat.money(liveDeliveryFeeLkr!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  'Collect ${LkrFormat.money(liveCollectLkr!)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.onlineGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ] else if (showPrepaidNote) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: cs.outlineVariant),
            ),
            Row(
              children: <Widget>[
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Paid online — nothing to collect',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _PrimaryAction(
            phase: phase,
            busy: busy,
            onOrderPickedUp: onOrderPickedUp,
            onDelivered: onDelivered,
          ),
        ],
      ),
    );
  }
}

/// Store → Customer progress — plain caps labels, current leg bold and
/// colored, the other muted, joined by a thin neutral rule.
class _LegStepper extends StatelessWidget {
  const _LegStepper({required this.vendorLeg, required this.legColor});

  final bool vendorLeg;
  final Color legColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ThemeData theme = Theme.of(context);

    TextStyle? style(bool active) => theme.textTheme.labelSmall?.copyWith(
      color: active ? legColor : cs.onSurfaceVariant,
      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      letterSpacing: 0.3,
    );

    return Row(
      children: <Widget>[
        Text('STORE', style: style(vendorLeg)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Divider(height: 1, color: cs.outlineVariant),
          ),
        ),
        Text('CUSTOMER', style: style(!vendorLeg)),
      ],
    );
  }
}

/// Plain outlined icon button — a thin border and a dark glyph, no fill.
class _OutlineIconButton extends StatelessWidget {
  const _OutlineIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: CircleBorder(side: BorderSide(color: cs.outlineVariant)),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: cs.onSurface),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.phase,
    required this.busy,
    required this.onOrderPickedUp,
    required this.onDelivered,
  });

  final RiderTripPhase phase;
  final bool busy;
  final VoidCallback onOrderPickedUp;
  final VoidCallback onDelivered;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final VoidCallback? onPressed;
    late final Color bg;
    late final IconData icon;

    switch (phase) {
      // One tap covers both "arrived" and "picked up" — arrival has no
      // separate backend state, so a confirmation step for it is just noise.
      case RiderTripPhase.navigateToVendor:
      case RiderTripPhase.atVendor:
        label = 'Picked up';
        onPressed = busy ? null : onOrderPickedUp;
        bg = AppColors.onlineGreen;
        icon = Icons.shopping_bag_rounded;
      // Stop legs only apply to passenger rides, never delivery orders.
      case RiderTripPhase.navigateToStop1:
      case RiderTripPhase.atStop1:
      case RiderTripPhase.navigateToStop2:
      case RiderTripPhase.atStop2:
      case RiderTripPhase.navigateToCustomer:
        label = 'Delivered';
        onPressed = busy ? null : onDelivered;
        bg = AppColors.dropoffRed;
        icon = Icons.check_circle_rounded;
      case RiderTripPhase.atCustomer:
        label = 'Confirm delivered';
        onPressed = busy ? null : onDelivered;
        bg = AppColors.dropoffRed;
        icon = Icons.check_circle_rounded;
    }

    return RiderSlideToConfirm(
      label: label,
      icon: icon,
      color: bg,
      busy: busy,
      onConfirmed: onPressed,
    );
  }
}
