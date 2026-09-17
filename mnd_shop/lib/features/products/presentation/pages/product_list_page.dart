import 'package:flutter/material.dart';
import 'package:mnd_shop/features/products/presentation/widgets/vendor_products_ui.dart';
import 'package:mnd_shop/features/products/data/vendor_product_repository.dart';

/// Upper bound for "low stock" band (1 through this many units).
const int vendorLowStockMax = 9;

/// Whole rupees stored as int; always show two decimals (e.g. `Rs. 350.00`).
String vendorPriceLabelLkr(int lkr) => 'Rs. ${lkr.toDouble().toStringAsFixed(2)}';

bool vendorCatalogCanAddProducts(
  String effectiveStoreId, {
  required int productCount,
  bool isGrocery = false,
}) {
  return effectiveStoreId.trim().isNotEmpty &&
      productCount < vendorProductLimitForShop(isGrocery: isGrocery);
}

/// Square thumbnail for product cards (size defaults for modern grid/list density).
class VendorProductThumb extends StatelessWidget {
  const VendorProductThumb({
    super.key,
    required this.url,
    this.size = 56,
    this.borderRadius = 14,
  });

  final String url;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fill = VendorProductsTheme.thumbPlaceholderFill(context);
    final Color iconColor = VendorProductsTheme.mutedText(context).withValues(alpha: 0.75);
    final Widget placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.inventory_2_outlined,
          size: size * 0.42,
          color: iconColor,
        ),
      ),
    );

    if (url.isEmpty) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) => SizedBox(
                  width: size,
                  height: size,
                  child: ColoredBox(
                    color: fill,
                    child: Icon(Icons.broken_image_outlined, color: iconColor),
                  ),
                ),
      ),
    );
  }
}
