import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/services/rider_location_service.dart';
import 'package:mnd_rider/features/auth/data/rider_auth_repository.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/order_request_session_provider.dart';
import 'package:mnd_rider/features/presence/data/rider_presence_repository.dart';

/// Signs out: stops GPS, goes offline, clears session state, FCM, Firebase Auth.
Future<void> riderSignOutAndClear(WidgetRef ref) async {
  try {
    await ref.read(riderLocationServiceProvider).setTrackingEnabled(false);
  } catch (_) {}
  try {
    await ref.read(riderDashboardProvider.notifier).setOnline(false);
  } catch (_) {}
  try {
    await ref.read(riderPresenceRepositoryProvider).setOnline(false);
  } catch (_) {}
  ref.read(orderRequestSessionProvider.notifier).resetSession();
  try {
    await ref.read(firebaseMessagingServiceProvider).unsubscribeOnSignOut();
  } catch (_) {}
  await ref.read(riderAuthRepositoryProvider).signOut();
}
