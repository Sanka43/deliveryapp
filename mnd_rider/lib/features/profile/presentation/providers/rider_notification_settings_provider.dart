import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/profile/data/rider_notification_settings_store.dart';
import 'package:mnd_rider/features/profile/domain/rider_notification_settings.dart';

final AsyncNotifierProvider<RiderNotificationSettingsNotifier,
        RiderNotificationSettings>
    riderNotificationSettingsProvider = AsyncNotifierProvider<
        RiderNotificationSettingsNotifier, RiderNotificationSettings>(
  RiderNotificationSettingsNotifier.new,
);

class RiderNotificationSettingsNotifier
    extends AsyncNotifier<RiderNotificationSettings> {
  @override
  Future<RiderNotificationSettings> build() async {
    return ref.read(riderNotificationSettingsStoreProvider).load();
  }

  Future<void> persist(RiderNotificationSettings next) async {
    state = const AsyncLoading<RiderNotificationSettings>();
    await ref.read(riderNotificationSettingsStoreProvider).save(next);
    state = AsyncData<RiderNotificationSettings>(next);
  }

  Future<void> setOrderOffers(bool value) async {
    final RiderNotificationSettings current =
        state.valueOrNull ?? RiderNotificationSettings.defaults;
    await persist(current.copyWith(orderOffersEnabled: value));
  }

  Future<void> setDeliveryUpdates(bool value) async {
    final RiderNotificationSettings current =
        state.valueOrNull ?? RiderNotificationSettings.defaults;
    await persist(current.copyWith(deliveryUpdatesEnabled: value));
  }

  Future<void> setEarningsAlerts(bool value) async {
    final RiderNotificationSettings current =
        state.valueOrNull ?? RiderNotificationSettings.defaults;
    await persist(current.copyWith(earningsAlertsEnabled: value));
  }

  Future<void> setPromotions(bool value) async {
    final RiderNotificationSettings current =
        state.valueOrNull ?? RiderNotificationSettings.defaults;
    await persist(current.copyWith(promotionsEnabled: value));
  }
}
