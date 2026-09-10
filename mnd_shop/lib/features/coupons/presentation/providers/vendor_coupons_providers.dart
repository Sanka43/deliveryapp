import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/coupons/data/vendor_coupons_repository.dart';
import 'package:mnd_shop/features/coupons/domain/vendor_coupon.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

final StreamProvider<List<VendorCoupon>> vendorCouponsListProvider =
    StreamProvider<List<VendorCoupon>>((Ref ref) {
  final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
  if (storeId.isEmpty) {
    return Stream<List<VendorCoupon>>.value(const <VendorCoupon>[]);
  }
  return ref.watch(vendorCouponsRepositoryProvider).watchCoupons(storeId);
});
