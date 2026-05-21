import 'package:shared_preferences/shared_preferences.dart';
import 'package:mnd_rider/core/notifications/rider_push_message.dart';

/// Reads notification toggles (same keys as [RiderNotificationSettingsStore]).
abstract final class RiderPushPreferences {
  static const String _prefix = 'mnd_rider_notify_';

  static Future<bool> isEnabledFor(RiderPushType type) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return switch (type) {
      RiderPushType.newDeliveryRequest =>
        prefs.getBool('${_prefix}offers') ?? true,
      RiderPushType.orderCancelled ||
      RiderPushType.deliveryCompleted =>
        prefs.getBool('${_prefix}delivery') ?? true,
      RiderPushType.earnings =>
        prefs.getBool('${_prefix}earnings') ?? true,
      RiderPushType.unknown => true,
    };
  }
}
