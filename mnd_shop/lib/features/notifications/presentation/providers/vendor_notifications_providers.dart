import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/notifications/data/vendor_notifications_repository.dart';
import 'package:mnd_shop/features/notifications/domain/vendor_notification.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

final StreamProvider<int> vendorUnreadNotificationCountProvider =
    StreamProvider<int>((Ref ref) {
  final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
  if (storeId.isEmpty) {
    return Stream<int>.value(0);
  }
  return ref.watch(vendorNotificationsRepositoryProvider).watchUnreadCount(storeId);
});

final StreamProvider<List<VendorNotification>> vendorNotificationsListProvider =
    StreamProvider<List<VendorNotification>>((Ref ref) {
  final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
  if (storeId.isEmpty) {
    return Stream<List<VendorNotification>>.value(<VendorNotification>[]);
  }
  return ref.watch(vendorNotificationsRepositoryProvider).watchNotifications(storeId);
});
