import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/shop_auth_state_provider.dart';
import 'package:mnd_shop/features/offers/data/vendor_offers_repository.dart';
import 'package:mnd_shop/features/offers/domain/vendor_offer.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

final StreamProvider<List<VendorOffer>> vendorOffersStreamProvider =
    StreamProvider<List<VendorOffer>>((Ref ref) {
  final User? user = ref.watch(shopAuthStateProvider).valueOrNull;
  final String storeId = ref.watch(vendorProductCatalogStoreIdProvider).trim();
  if (user == null || storeId.isEmpty) {
    return Stream<List<VendorOffer>>.value(const <VendorOffer>[]);
  }
  return ref.watch(vendorOffersRepositoryProvider).watchByStore(storeId);
});
