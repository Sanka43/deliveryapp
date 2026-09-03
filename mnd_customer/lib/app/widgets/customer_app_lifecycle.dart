import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/app/router/app_router.dart';
import 'package:mnd_delivery_app/core/services/fcm_message_router.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/services/fcm_token_repository.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/notification_settings_provider.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';

/// Wires FCM handlers, token sync, topic prefs, and in-app order status feedback.
class CustomerAppLifecycle extends ConsumerStatefulWidget {
  const CustomerAppLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CustomerAppLifecycle> createState() => _CustomerAppLifecycleState();
}

class _CustomerAppLifecycleState extends ConsumerState<CustomerAppLifecycle> {
  final Map<String, String> _lastOrderStatusById = <String, String>{};
  bool _initializedMessagingHandlers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapMessaging());
  }

  Future<void> _bootstrapMessaging() async {
    if (_initializedMessagingHandlers) {
      return;
    }
    _initializedMessagingHandlers = true;

    // Web push is opt-in via Notification Settings; skip boot-time FCM wiring.
    if (kIsWeb) {
      return;
    }

    if (Firebase.apps.isEmpty) {
      return;
    }

    // Do NOT request notification permission on splash/login — the system
    // dialog covers the auth UI and looks like the login page never opened.
    // Permission is requested after the user reaches the customer shell.
    await ref.read(notificationSettingsRepositoryProvider).loadAndSyncTopics();

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(FcmMessageRouter.navigateForMessage);
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      FcmTokenRepository().syncTokenForCurrentUser();
    });

    final RemoteMessage? initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && mounted) {
      FcmMessageRouter.navigateForMessage(initial);
    }

    final User? user = ref.read(firebaseAuthProvider).currentUser;
    if (user != null) {
      await FcmTokenRepository().syncTokenForCurrentUser();
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final BuildContext? context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    showMndSnackBar(
      context,
      '${FcmMessageRouter.humanTitle(message)}\n${FcmMessageRouter.humanBody(message)}',
      actionLabel: 'View',
      onAction: () => FcmMessageRouter.navigateForMessage(message),
      duration: const Duration(seconds: 5),
    );
  }

  void _onAuthChanged(User? user) {
    if (user == null) {
      _lastOrderStatusById.clear();
      return;
    }
    FcmTokenRepository().syncTokenForCurrentUser();
    ref.read(notificationSettingsRepositoryProvider).loadAndSyncTopics();
  }

  void _onOrdersUpdated(
    AsyncValue<List<CustomerOrderSummary>>? previous,
    AsyncValue<List<CustomerOrderSummary>> next,
  ) {
    final List<CustomerOrderSummary>? orders = next.valueOrNull;
    if (orders == null) {
      return;
    }

    final BuildContext? context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      for (final CustomerOrderSummary o in orders) {
        _lastOrderStatusById[o.id] = o.statusRaw;
      }
      return;
    }

    for (final CustomerOrderSummary order in orders) {
      final String? prior = _lastOrderStatusById[order.id];
      _lastOrderStatusById[order.id] = order.statusRaw;
      if (prior == null || prior == order.statusRaw) {
        continue;
      }
      showMndSnackBar(context, '${order.storeName}: ${order.displayStatus}', duration: const Duration(seconds: 4));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authStateUserProvider, (AsyncValue<User?>? prev, AsyncValue<User?> next) {
      _onAuthChanged(next.valueOrNull);
    });

    ref.listen<AsyncValue<List<CustomerOrderSummary>>>(
      customerOrdersStreamProvider,
      _onOrdersUpdated,
    );

    return widget.child;
  }
}
