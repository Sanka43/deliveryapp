/// Built-in order alert sounds available in the shop app.
enum VendorAlertSound {
  newOrder(
    id: 'new_order',
    label: 'New order chime',
    assetPath: 'sounds/new_order.mp3',
    androidRawName: 'new_order',
  ),
  youHaveANewOrder(
    id: 'you_have_a_new_order',
    label: 'You have a new order',
    assetPath: 'sounds/you_have_a_new_order.mp3',
    androidRawName: 'you_have_a_new_order',
  ),
  newNotification(
    id: 'new_notification',
    label: 'New notification',
    assetPath: 'sounds/new_notification.mp3',
    androidRawName: 'new_notification',
  ),
  bellNotification(
    id: 'bell_notification',
    label: 'Bell notification',
    assetPath: 'sounds/bell_notification.wav',
    androidRawName: 'bell_notification',
  ),
  dingDong(
    id: 'ding_dong',
    label: 'Ding dong',
    assetPath: 'sounds/ding_dong.wav',
    androidRawName: 'ding_dong',
  ),
  notificationBell(
    id: 'notification_bell',
    label: 'Notification bell',
    assetPath: 'sounds/notification_bell.wav',
    androidRawName: 'notification_bell',
  );

  const VendorAlertSound({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.androidRawName,
  });

  final String id;
  final String label;
  final String assetPath;

  /// Android `res/raw` resource name (no extension).
  final String androidRawName;

  static const VendorAlertSound defaultSound = VendorAlertSound.newOrder;

  /// SharedPreferences key for the selected [VendorAlertSound.id].
  static const String prefsKey = 'mnd_vendor_order_alert_sound_id';

  static VendorAlertSound fromId(String? id) {
    if (id == null || id.isEmpty) {
      return defaultSound;
    }
    for (final VendorAlertSound sound in VendorAlertSound.values) {
      if (sound.id == id) {
        return sound;
      }
    }
    return defaultSound;
  }
}
