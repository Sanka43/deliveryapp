import 'package:flutter/material.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/widgets/rider_order_request_overlay_host.dart';
import 'package:mnd_rider/features/notifications/presentation/widgets/rider_push_notification_listener.dart';
import 'package:mnd_rider/features/shell/presentation/widgets/rider_compliance_expiry_overlay.dart';

/// Wraps authenticated home routes: job offers and FCM. GPS tracking lives
/// on [MndRiderApp] so /trip and /ride still publish location.
class RiderAppShell extends StatelessWidget {
  const RiderAppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RiderPushNotificationListener(
      child: RiderComplianceExpiryOverlay(
        child: RiderOrderRequestOverlayHost(
          child: child,
        ),
      ),
    );
  }
}
