import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/billing/data/vendor_wallet_repository.dart';
import 'package:mnd_shop/features/billing/domain/vendor_payout.dart';
import 'package:mnd_shop/features/billing/domain/vendor_wallet.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

final StreamProvider<VendorWallet> vendorWalletProvider =
    StreamProvider<VendorWallet>((Ref ref) {
  final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
  if (storeId.isEmpty) {
    return Stream<VendorWallet>.value(VendorWallet.zero);
  }
  return ref.watch(vendorWalletRepositoryProvider).watchWallet(storeId);
});

final StreamProvider<List<VendorPayout>> vendorPayoutsListProvider =
    StreamProvider<List<VendorPayout>>((Ref ref) {
  final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
  if (storeId.isEmpty) {
    return Stream<List<VendorPayout>>.value(const <VendorPayout>[]);
  }
  return ref.watch(vendorWalletRepositoryProvider).watchPayouts(storeId);
});
