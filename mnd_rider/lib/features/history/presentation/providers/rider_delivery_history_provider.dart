import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/history/domain/rider_delivery_history_item.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';

final Provider<List<RiderDeliveryHistoryItem>> riderDeliveryHistoryProvider =
    Provider<List<RiderDeliveryHistoryItem>>((Ref ref) {
  final AsyncValue<List<RiderOrderDetail>> delivered =
      ref.watch(riderDeliveredHistoryProvider);
  return delivered.when(
    data: _mapHistory,
    loading: () => const <RiderDeliveryHistoryItem>[],
    error: (_, __) => const <RiderDeliveryHistoryItem>[],
  );
});

List<RiderDeliveryHistoryItem> _mapHistory(List<RiderOrderDetail> orders) {
  return orders
      .map(
        (RiderOrderDetail o) => RiderDeliveryHistoryItem(
          orderId: o.id,
          completedAtLabel: o.createdAt != null
              ? _formatWhen(o.createdAt!.toLocal())
              : '—',
          routeSummary: '${o.storeName} → dropoff',
          pickupLabel: o.pickupAddress ?? o.storeName,
          dropoffLabel: o.dropoffAddressSingleLine,
          payout: o.deliveryFeeLkr.toDouble(),
          completed: true,
          trackingNumber: o.trackingNumber,
        ),
      )
      .toList(growable: false);
}

String _formatWhen(DateTime dt) {
  final int hour12 = dt.hour > 12
      ? dt.hour - 12
      : (dt.hour == 0 ? 12 : dt.hour);
  final String ampm = dt.hour >= 12 ? 'pm' : 'am';
  final String m = dt.minute.toString().padLeft(2, '0');
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} · $hour12:$m $ampm';
}
