import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/app/providers/rider_auth_state_provider.dart';
import 'package:mnd_rider/core/notifications/rider_push_message.dart';
import 'package:mnd_rider/core/notifications/rider_push_navigation.dart';
import 'package:mnd_rider/core/services/firebase/firebase_messaging_service.dart';

/// Initializes FCM listeners and handles notification tap navigation.
class RiderPushNotificationListener extends ConsumerStatefulWidget {
  const RiderPushNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RiderPushNotificationListener> createState() =>
      _RiderPushNotificationListenerState();
}

class _RiderPushNotificationListenerState
    extends ConsumerState<RiderPushNotificationListener> {
  FirebaseMessagingService? _messaging;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryInit());
  }

  @override
  void dispose() {
    _messaging?.dispose();
    super.dispose();
  }

  Future<void> _tryInit() async {
    if (_initialized || ref.read(riderAuthStateProvider).valueOrNull == null) {
      return;
    }
    _initialized = true;
    _messaging = ref.read(firebaseMessagingServiceProvider);
    await _messaging!.initialize(
      onNotificationTap: _onNotificationTap,
    );
  }

  void _onNotificationTap(RiderPushMessage message) {
    if (!mounted) {
      return;
    }
    navigateForRiderPush(context, ref, message);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(riderAuthStateProvider, (
      AsyncValue<User?>? _,
      AsyncValue<User?> next,
    ) {
      if (next.valueOrNull != null) {
        _tryInit();
        ref.read(firebaseMessagingServiceProvider).syncDeviceToken();
      }
    });

    return widget.child;
  }
}
