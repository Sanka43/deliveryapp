import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/features/customer/data/customer_notifications_repository.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_notification.dart';

/// Rebinds when auth user changes.
final StreamProvider<List<CustomerNotification>>
    customerNotificationsListProvider =
    StreamProvider<List<CustomerNotification>>((Ref ref) {
  ref.watch(authStateUserProvider);
  return ref.watch(customerNotificationsRepositoryProvider).watchNotifications();
});

final StreamProvider<int> customerUnreadNotificationCountProvider =
    StreamProvider<int>((Ref ref) {
  ref.watch(authStateUserProvider);
  return ref.watch(customerNotificationsRepositoryProvider).watchUnreadCount();
});
