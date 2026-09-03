import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_catalog_metrics_snapshot.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';
import 'package:mnd_shop/features/products/presentation/pages/product_list_page.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_products_stream_provider.dart';

/// Shared inventory counts for dashboard hero and catalogue hub.
final Provider<VendorCatalogMetricsSnapshot> vendorCatalogMetricsProvider =
    Provider<VendorCatalogMetricsSnapshot>((Ref ref) {
  final List<VendorProduct> list =
      ref.watch(vendorProductsStreamProvider).valueOrNull ?? const <VendorProduct>[];
  if (list.isEmpty) {
    return VendorCatalogMetricsSnapshot.empty;
  }
  final int out = list
      .where((VendorProduct p) => p.manageStock && p.stockQty == 0)
      .length;
  final int low = list
      .where(
        (VendorProduct p) =>
            p.manageStock &&
            p.stockQty > 0 &&
            p.stockQty <= vendorLowStockMax,
      )
      .length;
  final int active = list.where((VendorProduct p) => p.active).length;
  return VendorCatalogMetricsSnapshot(
    total: list.length,
    outCount: out,
    lowCount: low,
    activeCount: active,
  );
});
