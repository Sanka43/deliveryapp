import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/features/customer/data/notification_settings_repository.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/notification_settings.dart';

final Provider<NotificationSettingsRepository> notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>((Ref ref) {
  return NotificationSettingsRepository();
});

final AutoDisposeAsyncNotifierProvider<NotificationSettingsNotifier, AppNotificationSettings>
    notificationSettingsProvider =
    AsyncNotifierProvider.autoDispose<NotificationSettingsNotifier, AppNotificationSettings>(
  NotificationSettingsNotifier.new,
);

class NotificationSettingsNotifier extends AutoDisposeAsyncNotifier<AppNotificationSettings> {
  @override
  Future<AppNotificationSettings> build() {
    return ref.read(notificationSettingsRepositoryProvider).loadAndSyncTopics();
  }

  Future<void> setOrderUpdates(bool value) async {
    final AppNotificationSettings before = state.requireValue;
    try {
      await ref.read(notificationSettingsRepositoryProvider).setOrderUpdates(value);
      state = AsyncValue<AppNotificationSettings>.data(
        before.copyWith(orderUpdates: value),
      );
    } catch (e, st) {
      state = AsyncValue<AppNotificationSettings>.data(before);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> setPromotions(bool value) async {
    final AppNotificationSettings before = state.requireValue;
    try {
      await ref.read(notificationSettingsRepositoryProvider).setPromotions(value);
      state = AsyncValue<AppNotificationSettings>.data(
        before.copyWith(promotions: value),
      );
    } catch (e, st) {
      state = AsyncValue<AppNotificationSettings>.data(before);
      Error.throwWithStackTrace(e, st);
    }
  }
}
