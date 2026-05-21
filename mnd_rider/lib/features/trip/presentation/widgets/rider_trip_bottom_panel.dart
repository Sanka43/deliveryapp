import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/trip/domain/rider_trip_phase.dart';
import 'package:mnd_rider/features/trip/presentation/providers/rider_trip_tracking_provider.dart';

/// Bottom sheet: ETA, address, and delivery action buttons.
class RiderTripBottomPanel extends ConsumerWidget {
  const RiderTripBottomPanel({
    super.key,
    required this.order,
    required this.phase,
    required this.vendorPosition,
    required this.customerPosition,
    required this.pickupAddress,
    required this.busy,
    required this.onArrivedAtStore,
    required this.onOrderPickedUp,
    required this.onDelivered,
    required this.onOpenMaps,
  });

  final RiderOrderDetail order;
  final RiderTripPhase phase;
  final LatLng? vendorPosition;
  final LatLng? customerPosition;
  final String pickupAddress;
  final bool busy;
  final VoidCallback onArrivedAtStore;
  final VoidCallback onOrderPickedUp;
  final VoidCallback onDelivered;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
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

    return Material(
      elevation: 20,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tracking ${order.referenceForDisplay}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 12),
              _EtaRow(eta: eta, phase: phase),
              const SizedBox(height: 14),
              _AddressCard(
                phase: phase,
                storeName: order.storeName,
                pickupAddress: pickupAddress,
                dropoffLine: order.dropoffAddressSingleLine,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: busy ? null : onOpenMaps,
                icon: const Icon(Icons.navigation_outlined),
                label: Text(vendorLeg ? 'Navigate to store' : 'Navigate to customer'),
              ),
              const SizedBox(height: 10),
              _PrimaryAction(
                phase: phase,
                busy: busy,
                onArrivedAtStore: onArrivedAtStore,
                onOrderPickedUp: onOrderPickedUp,
                onDelivered: onDelivered,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EtaRow extends StatelessWidget {
  const _EtaRow({required this.eta, required this.phase});

  final RiderTripEtaSnapshot eta;
  final RiderTripPhase phase;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            const Icon(Icons.schedule, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    eta.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${eta.durationText} · ${eta.distanceText}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              phase.isVendorLeg ? Icons.store_mall_directory_outlined : Icons.home_outlined,
              color: AppColors.primaryBlue,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.phase,
    required this.storeName,
    required this.pickupAddress,
    required this.dropoffLine,
  });

  final RiderTripPhase phase;
  final String storeName;
  final String pickupAddress;
  final String dropoffLine;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool vendor = phase.isVendorLeg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          vendor ? 'Pickup' : 'Dropoff',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          vendor ? storeName : 'Customer',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          vendor ? pickupAddress : dropoffLine,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.phase,
    required this.busy,
    required this.onArrivedAtStore,
    required this.onOrderPickedUp,
    required this.onDelivered,
  });

  final RiderTripPhase phase;
  final bool busy;
  final VoidCallback onArrivedAtStore;
  final VoidCallback onOrderPickedUp;
  final VoidCallback onDelivered;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final VoidCallback? onPressed;
    late final Color bg;

    switch (phase) {
      case RiderTripPhase.navigateToVendor:
        label = 'Arrived at Store';
        onPressed = busy ? null : onArrivedAtStore;
        bg = AppColors.primaryBlue;
      case RiderTripPhase.atVendor:
        label = 'Order Picked Up';
        onPressed = busy ? null : onOrderPickedUp;
        bg = AppColors.onlineGreen;
      case RiderTripPhase.navigateToCustomer:
      case RiderTripPhase.atCustomer:
        label = 'Delivered';
        onPressed = busy ? null : onDelivered;
        bg = AppColors.onlineGreen;
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
