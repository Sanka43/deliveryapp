import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/rider_live_location.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';

final AutoDisposeStreamProviderFamily<RiderLiveLocation?, String>
    riderLiveLocationStreamProvider =
    StreamProvider.autoDispose.family<RiderLiveLocation?, String>(
  (Ref ref, String riderId) {
    if (riderId.isEmpty) {
      return Stream<RiderLiveLocation?>.value(null);
    }
    return ref
        .watch(customerOrdersRepositoryProvider)
        .watchRiderLiveLocation(riderId);
  },
);
