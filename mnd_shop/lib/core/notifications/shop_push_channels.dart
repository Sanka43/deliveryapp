import 'package:mnd_shop/core/notifications/vendor_alert_sound.dart';

abstract final class ShopPushChannels {
  static const String ordersChannelName = 'Shop orders';
  static const String ordersChannelDescription =
      'New order and shop account alerts';

  /// Legacy default channel (kept for older installs).
  static const String ordersChannelId = 'mnd_shop_orders';

  static const String androidSound = 'new_order';

  /// Android 8+ locks channel sound at create time, so each sound gets its own
  /// channel id.
  static String ordersChannelIdFor(VendorAlertSound sound) =>
      'mnd_shop_orders_${sound.androidRawName}';
}
