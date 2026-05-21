import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mnd_rider/features/profile/domain/rider_notification_settings.dart';

const String _kPrefix = 'mnd_rider_notify_';

final Provider<RiderNotificationSettingsStore> riderNotificationSettingsStoreProvider =
    Provider<RiderNotificationSettingsStore>((Ref ref) {
  return RiderNotificationSettingsStore();
});

class RiderNotificationSettingsStore {
  Future<RiderNotificationSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return RiderNotificationSettings(
      orderOffersEnabled: prefs.getBool('${_kPrefix}offers') ?? true,
      deliveryUpdatesEnabled: prefs.getBool('${_kPrefix}delivery') ?? true,
      earningsAlertsEnabled: prefs.getBool('${_kPrefix}earnings') ?? true,
      promotionsEnabled: prefs.getBool('${_kPrefix}promos') ?? false,
    );
  }

  Future<void> save(RiderNotificationSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_kPrefix}offers', settings.orderOffersEnabled);
    await prefs.setBool('${_kPrefix}delivery', settings.deliveryUpdatesEnabled);
    await prefs.setBool('${_kPrefix}earnings', settings.earningsAlertsEnabled);
    await prefs.setBool('${_kPrefix}promos', settings.promotionsEnabled);
  }
}
