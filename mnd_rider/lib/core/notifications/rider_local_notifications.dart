import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mnd_rider/core/notifications/rider_push_channels.dart';
import 'package:mnd_rider/core/notifications/rider_push_message.dart';

/// Foreground / background display via [flutter_local_notifications].
class RiderLocalNotifications {
  RiderLocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _launchPayloadConsumed = false;

  /// Payload of the local notification that launched the app from terminated
  /// state, if any. Taps in that state never reach
  /// `onDidReceiveNotificationResponse`, so callers must check this once after
  /// initialization and navigate accordingly.
  static Future<String?> takeLaunchPayload() async {
    if (_launchPayloadConsumed) {
      return null;
    }
    _launchPayloadConsumed = true;
    final NotificationAppLaunchDetails? details =
        await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    return details.notificationResponse?.payload;
  }

  static Future<void> ensureInitialized({
    void Function(String? payload)? onTap,
  }) async {
    if (_initialized) {
      return;
    }

    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onTap?.call(response.payload);
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        RiderPushChannels.defaultChannelId,
        RiderPushChannels.defaultChannelName,
        description: RiderPushChannels.defaultChannelDescription,
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        RiderPushChannels.offersChannelId,
        RiderPushChannels.offersChannelName,
        description: RiderPushChannels.offersChannelDescription,
        importance: Importance.max,
        playSound: true,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        RiderPushChannels.earningsChannelId,
        RiderPushChannels.earningsChannelName,
        description: RiderPushChannels.earningsChannelDescription,
        importance: Importance.defaultImportance,
      ),
    );

    _initialized = true;
  }

  static Future<void> show(RiderPushMessage message) async {
    if (!_initialized) {
      debugPrint('RiderLocalNotifications: not initialized');
      return;
    }

    final String channelId = switch (message.type) {
      RiderPushType.newDeliveryRequest => RiderPushChannels.offersChannelId,
      RiderPushType.earnings ||
      RiderPushType.walletUpdate =>
        RiderPushChannels.earningsChannelId,
      _ => RiderPushChannels.defaultChannelId,
    };

    final int id = _notificationId(message);

    final AndroidNotificationDetails android = AndroidNotificationDetails(
      channelId,
      channelId == RiderPushChannels.offersChannelId
          ? RiderPushChannels.offersChannelName
          : channelId == RiderPushChannels.earningsChannelId
              ? RiderPushChannels.earningsChannelName
              : RiderPushChannels.defaultChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id,
      message.title,
      message.body,
      NotificationDetails(android: android, iOS: ios),
      payload: message.payloadForTap,
    );
  }

  static int _notificationId(RiderPushMessage message) {
    final String key = '${message.type.name}_${message.orderId ?? ''}';
    return key.hashCode & 0x7fffffff;
  }

  static RiderPushMessage? parsePayload(String? payload) =>
      payload == null ? null : RiderPushMessage.fromTapPayload(payload);
}
