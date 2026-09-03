import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mnd_shop/core/notifications/shop_push_channels.dart';
import 'package:mnd_shop/core/notifications/shop_push_message.dart';
import 'package:mnd_shop/core/notifications/vendor_alert_sound.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopLocalNotifications {
  ShopLocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static VendorAlertSound _alertSound = VendorAlertSound.defaultSound;

  static Future<VendorAlertSound> _loadAlertSound() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return VendorAlertSound.fromId(prefs.getString(VendorAlertSound.prefsKey));
  }

  static Future<void> ensureInitialized({
    void Function(String? payload)? onTap,
  }) async {
    if (!_initialized) {
      const AndroidInitializationSettings android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          onTap?.call(response.payload);
        },
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      _initialized = true;
    }

    _alertSound = await _loadAlertSound();
    await ensureAllOrdersChannels();
  }

  /// Creates the FCM default channel plus every tone-specific channel.
  /// Channel sound is immutable after first create, so each sound has its own id.
  static Future<void> ensureAllOrdersChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) {
      return;
    }

    // Old-generation channels may exist with a broken (silent) sound locked in
    // by Android; remove them so only the current v2 channels remain.
    for (final String legacyId in ShopPushChannels.legacyChannelIds) {
      try {
        await androidPlugin.deleteNotificationChannel(channelId: legacyId);
      } catch (_) {
        // Best effort: a failed delete must not block channel setup.
      }
    }

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        ShopPushChannels.ordersChannelId,
        ShopPushChannels.ordersChannelName,
        description: ShopPushChannels.ordersChannelDescription,
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(
          ShopPushChannels.androidSound,
        ),
      ),
    );

    for (final VendorAlertSound sound in VendorAlertSound.values) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          ShopPushChannels.ordersChannelIdFor(sound),
          ShopPushChannels.ordersChannelName,
          description: ShopPushChannels.ordersChannelDescription,
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(sound.androidRawName),
        ),
      );
    }
  }

  /// Creates (or reuses) the Android channel for [sound] and marks it selected.
  static Future<void> ensureOrdersChannel(VendorAlertSound sound) async {
    _alertSound = sound;
    await ensureAllOrdersChannels();
  }

  static Future<VendorAlertSound> currentAlertSound() async {
    _alertSound = await _loadAlertSound();
    return _alertSound;
  }

  static Future<void> show(ShopPushMessage message) async {
    if (!_initialized) {
      debugPrint('ShopLocalNotifications: not initialized');
      return;
    }

    _alertSound = await _loadAlertSound();
    await ensureOrdersChannel(_alertSound);

    final AndroidNotificationDetails android = AndroidNotificationDetails(
      ShopPushChannels.ordersChannelIdFor(_alertSound),
      ShopPushChannels.ordersChannelName,
      channelDescription: ShopPushChannels.ordersChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      sound: RawResourceAndroidNotificationSound(_alertSound.androidRawName),
    );

    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id: message.payloadForTap.hashCode & 0x7fffffff,
      title: message.title,
      body: message.body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: message.payloadForTap,
    );
  }

  static ShopPushMessage? parsePayload(String? payload) =>
      payload == null ? null : ShopPushMessage.fromTapPayload(payload);
}
