import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

final StreamProvider<VendorOrderBoard> vendorOrderBoardProvider =
    StreamProvider<VendorOrderBoard>((Ref ref) {
  final String t = ref.watch(vendorEffectiveStoreIdProvider).trim();
  if (t.isEmpty) {
    return Stream<VendorOrderBoard>.value(VendorOrderBoard.empty);
  }
  return ref.watch(vendorOrdersRepositoryProvider).watchOrderBoard(t);
});

final StreamProvider<bool> vendorStoreActiveProvider = StreamProvider<bool>(
  (Ref ref) {
    final String t = ref.watch(vendorEffectiveStoreIdProvider).trim();
    if (t.isEmpty) {
      return Stream<bool>.value(true);
    }
    return ref.watch(vendorOrdersRepositoryProvider).watchVendorActive(t);
  },
);
