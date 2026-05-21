import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/core/services/rider_location_service.dart';
import 'package:mnd_rider/features/orders/presentation/providers/rider_active_order_provider.dart';

/// Starts/stops GPS publishing when online or on an active delivery.
class RiderLocationTrackingLifecycle extends ConsumerStatefulWidget {
  const RiderLocationTrackingLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RiderLocationTrackingLifecycle> createState() =>
      _RiderLocationTrackingLifecycleState();
}

class _RiderLocationTrackingLifecycleState
    extends ConsumerState<RiderLocationTrackingLifecycle> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTracking();
    });
  }

  void _syncTracking() {
    final bool enabled = ref.read(riderLocationTrackingEnabledProvider);
    ref.read(riderLocationServiceProvider).setTrackingEnabled(enabled);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(riderLocationTrackingEnabledProvider,
        (bool? prev, bool next) {
      ref.read(riderLocationServiceProvider).setTrackingEnabled(next);
    });

    return widget.child;
  }
}
