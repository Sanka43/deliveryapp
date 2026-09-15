import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/billing/data/vendor_product_cash_repository.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

export 'package:mnd_shop/features/billing/data/vendor_product_cash_repository.dart'
    show VendorProductCashBucket;

/// Four independent providers (one per productCashStatus) rather than one
/// combined stream — no stream-combining package (rxdart) is a direct
/// dependency of this app, so this mirrors how vendor_payouts_page.dart
/// already watches vendorWalletProvider and vendorPayoutsListProvider side
/// by side instead of merging them.
StreamProvider<VendorProductCashBucket> _statusProvider(String status) {
  return StreamProvider<VendorProductCashBucket>((Ref ref) {
    final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
    if (storeId.isEmpty) {
      return Stream<VendorProductCashBucket>.value((totalLkr: 0, count: 0));
    }
    return ref.watch(vendorProductCashRepositoryProvider).watchStatus(storeId, status);
  });
}

final StreamProvider<VendorProductCashBucket> vendorProductCashOwedProvider =
    _statusProvider('owed');

final StreamProvider<VendorProductCashBucket> vendorProductCashRequestedProvider =
    _statusProvider('remittance_requested');

final StreamProvider<VendorProductCashBucket> vendorProductCashWithAdminProvider =
    _statusProvider('remitted_to_admin');

final StreamProvider<VendorProductCashBucket> vendorProductCashSettledProvider =
    _statusProvider('settled_to_shop');
