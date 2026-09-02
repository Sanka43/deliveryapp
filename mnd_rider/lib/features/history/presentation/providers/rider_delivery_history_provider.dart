import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/history/domain/rider_delivery_history_item.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';

const int _deliveredHistoryPageSize = 100;
const int _tripHistoryPageSize = 40;

/// How many pages of history the "Load more" action has requested (starts
/// at 1 page). Scoped to the history screen only.
final StateProvider<int> riderHistoryPageMultiplierProvider =
    StateProvider<int>((Ref ref) => 1);

/// Which kind of trip the history screen's segmented filter is showing.
enum RiderHistoryFilter { all, delivery, ride }

/// Scoped to the history screen only, same as the page multiplier above.
final StateProvider<RiderHistoryFilter> riderHistoryFilterProvider =
    StateProvider<RiderHistoryFilter>((Ref ref) => RiderHistoryFilter.all);

/// Delivered-order history at the current page size. Kept separate from
/// [riderDeliveredHistoryProvider] (which earnings aggregates watch at a
/// fixed limit) so "Load more" here never changes what earnings sees.
final StreamProvider<List<RiderOrderDetail>> riderDeliveredHistoryPagedProvider =
    StreamProvider<List<RiderOrderDetail>>((Ref ref) {
  final int multiplier = ref.watch(riderHistoryPageMultiplierProvider);
  return ref.watch(riderOrdersRepositoryProvider).watchDeliveredHistory(
        limit: _deliveredHistoryPageSize * multiplier,
      );
});

final StreamProvider<List<RiderPassengerTrip>> riderCompletedTripsProvider =
    StreamProvider<List<RiderPassengerTrip>>((Ref ref) {
  final int multiplier = ref.watch(riderHistoryPageMultiplierProvider);
  return ref.watch(riderTripsRepositoryProvider).watchMyCompletedTrips(
        limit: _tripHistoryPageSize * multiplier,
      );
});

/// True when either source came back at its current page cap, meaning there
/// may be older history beyond what's loaded. Firestore has no cheap
/// total-count query, so "the page came back full" is the standard signal.
final Provider<bool> riderDeliveryHistoryHasMoreProvider =
    Provider<bool>((Ref ref) {
  final int multiplier = ref.watch(riderHistoryPageMultiplierProvider);
  final int deliveredCount =
      ref.watch(riderDeliveredHistoryPagedProvider).valueOrNull?.length ?? 0;
  final int tripsCount =
      ref.watch(riderCompletedTripsProvider).valueOrNull?.length ?? 0;
  return deliveredCount >= _deliveredHistoryPageSize * multiplier ||
      tripsCount >= _tripHistoryPageSize * multiplier;
});

final Provider<List<RiderDeliveryHistoryItem>> riderDeliveryHistoryProvider =
    Provider<List<RiderDeliveryHistoryItem>>((Ref ref) {
  final AsyncValue<List<RiderOrderDetail>> delivered =
      ref.watch(riderDeliveredHistoryPagedProvider);
  final AsyncValue<List<RiderPassengerTrip>> trips =
      ref.watch(riderCompletedTripsProvider);

  final List<RiderDeliveryHistoryItem> items = <RiderDeliveryHistoryItem>[
    ...delivered.maybeWhen(
      data: _mapDeliveryHistory,
      orElse: () => const <RiderDeliveryHistoryItem>[],
    ),
    ...trips.maybeWhen(
      data: _mapTripHistory,
      orElse: () => const <RiderDeliveryHistoryItem>[],
    ),
  ];

  items.sort((RiderDeliveryHistoryItem a, RiderDeliveryHistoryItem b) {
    final DateTime? at = a.completedAt;
    final DateTime? bt = b.completedAt;
    if (at == null && bt == null) {
      return 0;
    }
    if (at == null) {
      return 1;
    }
    if (bt == null) {
      return -1;
    }
    return bt.compareTo(at);
  });
  return items;
});

List<RiderDeliveryHistoryItem> _mapDeliveryHistory(
  List<RiderOrderDetail> orders,
) {
  return orders
      .map(
        (RiderOrderDetail o) => RiderDeliveryHistoryItem(
          orderId: o.id,
          completedAt: o.createdAt?.toLocal(),
          completedAtLabel: o.createdAt != null
              ? _formatWhen(o.createdAt!.toLocal())
              : '—',
          routeSummary: '${o.storeName} → dropoff',
          pickupLabel: o.pickupAddress ?? o.storeName,
          dropoffLabel: o.dropoffAddressSingleLine,
          payout: o.deliveryFeeLkr.toDouble(),
          completed: true,
          trackingNumber: o.trackingNumber,
          kind: RiderHistoryKind.delivery,
        ),
      )
      .toList(growable: false);
}

List<RiderDeliveryHistoryItem> _mapTripHistory(List<RiderPassengerTrip> trips) {
  return trips
      .map(
        (RiderPassengerTrip t) => RiderDeliveryHistoryItem(
          orderId: t.id,
          completedAt: t.createdAt?.toLocal(),
          completedAtLabel: t.createdAt != null
              ? _formatWhen(t.createdAt!.toLocal())
              : '—',
          routeSummary: t.pickupLabel.isEmpty && t.dropoffLabel.isEmpty
              ? 'Passenger ride'
              : '${t.pickupLabel.isEmpty ? 'Pickup' : t.pickupLabel} → '
                  '${t.dropoffLabel.isEmpty ? 'Dropoff' : t.dropoffLabel}',
          pickupLabel: t.pickupLabel.isEmpty ? 'Pickup' : t.pickupLabel,
          dropoffLabel: t.dropoffLabel.isEmpty ? 'Dropoff' : t.dropoffLabel,
          payout: t.estimatedFareLkr.toDouble(),
          completed: t.status.toLowerCase() == 'completed',
          trackingNumber: null,
          kind: RiderHistoryKind.ride,
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
