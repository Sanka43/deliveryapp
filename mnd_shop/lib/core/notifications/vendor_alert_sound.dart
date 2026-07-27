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
