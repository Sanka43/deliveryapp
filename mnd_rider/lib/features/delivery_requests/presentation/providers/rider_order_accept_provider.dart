import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/features/delivery_requests/data/rider_order_notifications_repository.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

class RiderOrderAcceptResult {
  const RiderOrderAcceptResult._({this.error, this.order, this.orderId});

  final String? error;
  final RiderOrderDetail? order;
  final String? orderId;

  bool get isSuccess => error == null;

  String? get tripOrderId => order?.id ?? orderId;

  factory RiderOrderAcceptResult.success(RiderOrderDetail order) =>
      RiderOrderAcceptResult._(order: order, orderId: order.id);

  factory RiderOrderAcceptResult.claimedWithoutDetail(String orderId) =>
      RiderOrderAcceptResult._(orderId: orderId);

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

    RiderOrderDetail? order =
        await ref.read(riderOrdersRepositoryProvider).fetchOrderDetail(request.orderId);
    if (order == null) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      order = await ref
          .read(riderOrdersRepositoryProvider)
          .fetchOrderDetail(request.orderId);
    }
    if (order == null) {
      return RiderOrderAcceptResult.claimedWithoutDetail(request.orderId);
    }
    return RiderOrderAcceptResult.success(order);
  };
});
