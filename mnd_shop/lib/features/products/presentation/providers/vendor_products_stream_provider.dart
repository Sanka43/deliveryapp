import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/shop_auth_state_provider.dart';
import 'package:mnd_shop/features/products/data/vendor_product_repository.dart';
import 'package:mnd_shop/features/products/domain/product_option_labels.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

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

/// Custom food types remembered for this shop (vendor doc + existing products).
/// Shown as chips on add/edit product when using Type × Size pricing.
final Provider<List<String>> shopRememberedCustomFoodTypesProvider =
    Provider<List<String>>((Ref ref) {
  final Map<String, dynamic>? account =
      ref.watch(vendorAccountDocDataProvider).valueOrNull;
  final Map<String, dynamic>? catalogStore =
      ref.watch(vendorCatalogStoreDocDataProvider).valueOrNull;
  final List<VendorProduct> products =
      ref.watch(vendorProductsStreamProvider).valueOrNull ??
          const <VendorProduct>[];

  final List<String> fromProducts = customFoodTypesFromOptionNames(
    products.expand(
      (VendorProduct p) => p.sizeOptions.map((ProductSizeOption o) => o.name),
    ),
  );

  return mergeCustomFoodTypeLists(<Iterable<String>>[
    parseCustomFoodTypesField(account?['customFoodTypes']),
    parseCustomFoodTypesField(catalogStore?['customFoodTypes']),
    fromProducts,
  ]);
});
