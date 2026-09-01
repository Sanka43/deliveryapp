import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/notifications/rider_push_message.dart';
import 'package:mnd_rider/features/shell/presentation/providers/rider_shell_tab_provider.dart';

/// Routes the user when a push notification is opened.
void navigateForRiderPush(
  BuildContext context,
  WidgetRef ref,
  RiderPushMessage message,
) {
  switch (message.type) {
    case RiderPushType.newDeliveryRequest:
      ref.read(riderShellTabIndexProvider.notifier).state = 0;
      context.go(RoutePaths.shell);
    case RiderPushType.orderCancelled:
      ref.read(riderShellTabIndexProvider.notifier).state = 1;
      if (message.orderId != null && message.orderId!.isNotEmpty) {
        context.push('${RoutePaths.orderDetail}/${message.orderId}');
      } else {
        context.go(RoutePaths.shell);
      }
    case RiderPushType.deliveryCompleted:
      ref.read(riderShellTabIndexProvider.notifier).state = 1;
      if (message.orderId != null && message.orderId!.isNotEmpty) {
        context.push('${RoutePaths.orderDetail}/${message.orderId}');
      } else {
        context.push(RoutePaths.history);
      }
    case RiderPushType.earnings:
      ref.read(riderShellTabIndexProvider.notifier).state = 2;
      context.go(RoutePaths.shell);
    case RiderPushType.rideUpdate:
      ref.read(riderShellTabIndexProvider.notifier).state = 1;
      if (message.tripId != null && message.tripId!.isNotEmpty) {
        context.push('${RoutePaths.ride}/${message.tripId}');
      } else {
        context.go(RoutePaths.shell);
      }
    case RiderPushType.documentsExpiring:
    case RiderPushType.documentsExpired:
      ref.read(riderShellTabIndexProvider.notifier).state = 3;
      context.push(RoutePaths.renewDocuments);
    case RiderPushType.walletUpdate:
      ref.read(riderShellTabIndexProvider.notifier).state = 2;
      context.go(RoutePaths.shell);
    case RiderPushType.unknown:
      context.go(RoutePaths.shell);
  }
}
