import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/shop_auth_state_provider.dart';
import 'package:mnd_shop/features/products/data/vendor_product_repository.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';

/// Catalogue for the signed-in vendor only: [products.storeId] must equal [User.uid].
/// Never follows a mis-linked `vendorStoreId` (prevents seeing another shop's menu, e.g. Rangan).
final StreamProvider<List<VendorProduct>> vendorProductsStreamProvider =
    StreamProvider<List<VendorProduct>>((Ref ref) {
  final User? user = ref.watch(shopAuthStateProvider).valueOrNull;
  if (user == null) {
    return Stream<List<VendorProduct>>.value(const <VendorProduct>[]);
  }
  final String uid = user.uid.trim();
  if (uid.isEmpty) {
    return Stream<List<VendorProduct>>.value(const <VendorProduct>[]);
  }
  return ref.watch(vendorProductRepositoryProvider).watchByStore(uid).map(
        (List<VendorProduct> list) => list
            .where((VendorProduct p) => p.storeId.trim() == uid)
            .toList(growable: false),
      );
});
