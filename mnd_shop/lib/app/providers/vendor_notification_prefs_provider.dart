import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kOrderAlertSoundKey = 'mnd_vendor_order_alert_sound';
const String _kInAppOrderAlertsKey = 'mnd_vendor_in_app_order_alerts';

final AsyncNotifierProvider<VendorNotificationPrefsNotifier, VendorNotificationPrefs>
    vendorNotificationPrefsProvider =
    AsyncNotifierProvider<VendorNotificationPrefsNotifier, VendorNotificationPrefs>(
  VendorNotificationPrefsNotifier.new,
);

class VendorNotificationPrefs {
  const VendorNotificationPrefs({
    required this.orderAlertSound,
    required this.inAppOrderAlerts,
  });

  final bool orderAlertSound;
  final bool inAppOrderAlerts;

  VendorNotificationPrefs copyWith({
    bool? orderAlertSound,
    bool? inAppOrderAlerts,
  }) {
    return VendorNotificationPrefs(
      orderAlertSound: orderAlertSound ?? this.orderAlertSound,
      inAppOrderAlerts: inAppOrderAlerts ?? this.inAppOrderAlerts,
    );
  }
}

class VendorNotificationPrefsNotifier extends AsyncNotifier<VendorNotificationPrefs> {
  @override
  Future<VendorNotificationPrefs> build() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return VendorNotificationPrefs(
      orderAlertSound: p.getBool(_kOrderAlertSoundKey) ?? true,
      inAppOrderAlerts: p.getBool(_kInAppOrderAlertsKey) ?? true,
    );
  }

  Future<void> setOrderAlertSound(bool value) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setBool(_kOrderAlertSoundKey, value);
    state = AsyncData<VendorNotificationPrefs>(
      state.requireValue.copyWith(orderAlertSound: value),
    );
  }

  Future<void> setInAppOrderAlerts(bool value) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setBool(_kInAppOrderAlertsKey, value);
    state = AsyncData<VendorNotificationPrefs>(
      state.requireValue.copyWith(inAppOrderAlerts: value),
    );
  }
}

/// Whether to play the new-order alert sound.
final Provider<bool> vendorOrderAlertSoundEnabledProvider = Provider<bool>((Ref ref) {
  return ref.watch(vendorNotificationPrefsProvider).valueOrNull?.orderAlertSound ?? true;
});

/// Whether to show the in-app new-order dialog.
final Provider<bool> vendorInAppOrderAlertsEnabledProvider = Provider<bool>((Ref ref) {
  return ref.watch(vendorNotificationPrefsProvider).valueOrNull?.inAppOrderAlerts ?? true;
});
