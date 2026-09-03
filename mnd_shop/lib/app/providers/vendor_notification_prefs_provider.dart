import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/notifications/shop_local_notifications.dart';
import 'package:mnd_shop/core/notifications/vendor_alert_sound.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
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
    required this.alertTone,
  });

  /// Whether to play sound for in-app new-order alerts.
  final bool orderAlertSound;

  /// Whether to show the in-app new-order dialog.
  final bool inAppOrderAlerts;

  /// Preferred push / local notification tone.
  final VendorAlertSound alertTone;

  VendorNotificationPrefs copyWith({
    bool? orderAlertSound,
    bool? inAppOrderAlerts,
    VendorAlertSound? alertTone,
  }) {
    return VendorNotificationPrefs(
      orderAlertSound: orderAlertSound ?? this.orderAlertSound,
      inAppOrderAlerts: inAppOrderAlerts ?? this.inAppOrderAlerts,
      alertTone: alertTone ?? this.alertTone,
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
      alertTone: VendorAlertSound.fromId(p.getString(VendorAlertSound.prefsKey)),
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

  Future<void> setAlertTone(VendorAlertSound sound) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(VendorAlertSound.prefsKey, sound.id);
    await ShopLocalNotifications.ensureOrdersChannel(sound);

    final String storeId =
        ref.read(vendorEffectiveStoreIdProvider).trim();
    if (storeId.isNotEmpty) {
      await ref
          .read(shopFirebaseMessagingServiceProvider)
          .syncNotificationChannelPrefs(vendorId: storeId, sound: sound);
    }

    state = AsyncData<VendorNotificationPrefs>(
      state.requireValue.copyWith(alertTone: sound),
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

/// Selected push / in-app alert tone.
final Provider<VendorAlertSound> vendorAlertToneProvider =
    Provider<VendorAlertSound>((Ref ref) {
  return ref.watch(vendorNotificationPrefsProvider).valueOrNull?.alertTone ??
      VendorAlertSound.defaultSound;
});
