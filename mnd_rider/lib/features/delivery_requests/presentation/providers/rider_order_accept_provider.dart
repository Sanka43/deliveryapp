import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/features/delivery_requests/data/rider_order_notifications_repository.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

class RiderOrderAcceptResult {
  const RiderOrderAcceptResult._({this.error, this.order});

  final String? error;
  final RiderOrderDetail? order;

  bool get isSuccess => error == null && order != null;

  factory RiderOrderAcceptResult.success(RiderOrderDetail order) =>
      RiderOrderAcceptResult._(order: order);

  factory RiderOrderAcceptResult.failure(String message) =>
      RiderOrderAcceptResult._(error: message);
}

final Provider<Future<RiderOrderAcceptResult> Function(RiderDeliveryRequest)>
    riderOrderAcceptProvider =
    Provider<Future<RiderOrderAcceptResult> Function(RiderDeliveryRequest)>((Ref ref) {
  return (RiderDeliveryRequest request) async {
    final String? claimError =
        await ref.read(riderOrdersRepositoryProvider).claimOrder(request.orderId);
    if (claimError != null) {
      return RiderOrderAcceptResult.failure(claimError);
    }

    final User? user = ref.read(firebaseAuthProvider).currentUser;
    final String riderName =
        user?.displayName?.trim().isNotEmpty == true ? user!.displayName!.trim() : 'Your rider';

    await ref.read(riderOrderNotificationsRepositoryProvider).notifyOrderAccepted(
          request: request,
          riderName: riderName,
        );

    final RiderOrderDetail? order =
        await ref.read(riderOrdersRepositoryProvider).fetchOrderDetail(request.orderId);
    if (order == null) {
      return RiderOrderAcceptResult.failure('Order not found after accept.');
    }
    return RiderOrderAcceptResult.success(order);
  };
});
