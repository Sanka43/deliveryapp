import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
const Set<String> _activeStatuses = <String>{
  'out_for_delivery',
  'picked_up',
  'on_the_way',
};

final Provider<String?> activeRiderOrderIdProvider = Provider<String?>((Ref ref) {
  final List<RiderAssignedOrder> assigned =
      ref.watch(assignedRiderOrdersProvider).valueOrNull ??
          const <RiderAssignedOrder>[];
  for (final RiderAssignedOrder o in assigned) {
    if (_activeStatuses.contains(o.status)) {
      return o.id;
    }
  }
  return null;
});

final Provider<bool> riderHasActiveDeliveryProvider = Provider<bool>((Ref ref) {
  return ref.watch(activeRiderOrderIdProvider) != null;
});

final Provider<bool> riderLocationTrackingEnabledProvider =
    Provider<bool>((Ref ref) {
  final bool online = ref.watch(riderDashboardProvider).isOnline;
  final bool active = ref.watch(riderHasActiveDeliveryProvider);
  return online || active;
});
