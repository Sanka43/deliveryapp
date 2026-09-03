import 'package:mnd_shop/core/notifications/vendor_alert_sound.dart';

abstract final class ShopPushChannels {
  static const String ordersChannelName = 'Shop orders';
  static const String ordersChannelDescription =
      'New order and shop account alerts';

  /// Default channel targeted by FCM when the vendor doc has no explicit
  /// channel preference. Versioned (`v2`) because Android locks a channel's
  /// sound at first creation: older installs may hold same-named channels that
  /// were created without a valid sound resource, and the only reliable repair
  /// is a fresh channel id (deleting and recreating the same id restores the
  /// old, broken settings).
  static const String ordersChannelId = 'mnd_shop_orders_v2';

  static const String androidSound = 'new_order';

  /// Android 8+ locks channel sound at create time, so each sound gets its own
  /// channel id.
  static String ordersChannelIdFor(VendorAlertSound sound) =>
      'mnd_shop_orders_v2_${sound.androidRawName}';

  /// Channel ids used by earlier releases. Deleted at startup so devices stuck
  /// with a silent channel recover once the app updates.
  static List<String> get legacyChannelIds => <String>[
        'mnd_shop_orders',
        for (final VendorAlertSound sound in VendorAlertSound.values)
          'mnd_shop_orders_${sound.androidRawName}',
      ];
}
