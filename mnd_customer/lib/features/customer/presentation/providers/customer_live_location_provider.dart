import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/features/customer/data/customer_live_location_service.dart';

final AutoDisposeStreamProvider<CustomerLiveLocationLabel>
    customerLiveLocationProvider =
    StreamProvider.autoDispose<CustomerLiveLocationLabel>((Ref ref) {
  return CustomerLiveLocationService.watch();
});
