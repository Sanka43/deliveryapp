import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/router/app_router.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';

/// Routes the user from an FCM payload to order/ride detail or tracking.
class FcmMessageRouter {
  FcmMessageRouter._();

  static String? orderIdFromMessage(RemoteMessage message) {
    final Map<String, dynamic> data = message.data;
    final String? direct = data['orderId'] as String? ?? data['order_id'] as String?;
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    return null;
  }

  static String? tripIdFromMessage(RemoteMessage message) {
    final Map<String, dynamic> data = message.data;
    final String? direct = data['tripId'] as String? ?? data['trip_id'] as String?;
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    return null;
  }

  static void navigateForMessage(RemoteMessage message) {
    final BuildContext? context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    final String? tripId = tripIdFromMessage(message);
    if (tripId != null) {
      final bool openTracking =
          message.data['screen'] == 'tracking' ||
          message.data['openTracking'] == 'true';
      if (openTracking) {
        context.push(AppRoutes.customerRideTracking(tripId));
      } else {
        context.push(AppRoutes.customerRideTrip(tripId));
      }
      return;
    }

    final String? orderId = orderIdFromMessage(message);
    if (orderId == null) {
      return;
    }
    final bool openTracking =
        message.data['screen'] == 'tracking' || message.data['openTracking'] == 'true';
    if (openTracking) {
      context.push(AppRoutes.customerOrderLiveTracking(orderId));
    } else {
      context.push('${AppRoutes.customerOrders}/$orderId');
    }
  }

  static String humanTitle(RemoteMessage message) {
    final RemoteNotification? n = message.notification;
    if (n?.title != null && n!.title!.trim().isNotEmpty) {
      return n.title!.trim();
    }
    if (tripIdFromMessage(message) != null) {
      final String? status = message.data['status'] as String?;
      if (status != null && status.isNotEmpty) {
        return 'Ride update: $status';
      }
      return 'Ride update';
    }
    final String? status = message.data['status'] as String?;
    if (status != null && status.isNotEmpty) {
      return 'Order update: $status';
    }
    return 'Order update';
  }

  static String humanBody(RemoteMessage message) {
    final RemoteNotification? n = message.notification;
    if (n?.body != null && n!.body!.trim().isNotEmpty) {
      return n.body!.trim();
    }
    return 'Tap to open';
  }
}
