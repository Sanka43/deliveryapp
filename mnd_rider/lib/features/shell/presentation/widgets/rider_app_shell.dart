import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/widgets/rider_order_request_overlay_host.dart';
import 'package:mnd_rider/features/notifications/presentation/widgets/rider_push_notification_listener.dart';
import 'package:mnd_rider/features/shell/presentation/widgets/rider_location_tracking_lifecycle.dart';

/// Wraps authenticated routes: location tracking, job offers, FCM.
class RiderAppShell extends StatelessWidget {
  const RiderAppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RiderPushNotificationListener(
      child: RiderLocationTrackingLifecycle(
        child: RiderOrderRequestOverlayHost(
          child: child,
        ),
      ),
    );
  }
}
