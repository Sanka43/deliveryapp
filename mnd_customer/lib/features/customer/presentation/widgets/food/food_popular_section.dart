import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/food_catalog_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/food/food_dish_shortcuts.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/product_card.dart';
import 'package:mnd_delivery_app/features/store/presentation/widgets/product_details_bottom_sheet.dart';

class FoodPopularSection extends ConsumerWidget {
  const FoodPopularSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SearchProduct>> productsAsync =
        ref.watch(browseProductsStreamProvider);
    final AsyncValue<List<SearchStore>> storesAsync =
        ref.watch(browseStoresStreamProvider);
    final List<SearchProduct> popular = ref.watch(popularFoodProductsProvider);

    return HomeSectionEntrance(
      delay: Duration.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const MndSectionHeader(title: 'Popular'),
          const SizedBox(height: AppSpacing.sm),
          const FoodDishShortcuts(),
          const SizedBox(height: AppSpacing.sm),
          productsAsync.when(
            loading: () => const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (Object error, _) => _InlineMessage(
              catalogLoadErrorMessage(error),
            ),
            data: (_) {
              if (popular.isEmpty) {
                return const _InlineMessage('No popular food items yet.');
              }

              final Map<String, SearchStore> storeById = storesAsync.maybeWhen(
                data: (List<SearchStore> stores) => <String, SearchStore>{
                  for (final SearchStore s in stores) s.id: s,
                },
                orElse: () => <String, SearchStore>{},
              );

              return SizedBox(
                height: ProductCard.homeListHeightCompact,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: popular.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    final SearchProduct item = popular[index];
                    final SearchStore? store = storeById[item.storeId];

                    if (item.storeId.isEmpty) {
                      return ProductCard(
                        premium: true,
                        showAddToCartButton: false,
                        productKey: item.lookupKey,
                        name: item.name,
                        storeName: item.storeName,
                        priceLabel: item.price,
                        imageUrl: item.imageUrl,
                        isAvailable: item.isInStock,
                        onAddToCart: () {},
                      );
                    }

                    return ProductCard(
                      premium: true,
                      showAddToCartButton: false,
                      productKey: item.lookupKey,
                      name: item.name,
                      storeName: item.storeName,
                      etaLabel: store?.eta,
                      rating: store?.rating,
                      priceLabel: item.price,
                      imageUrl: item.imageUrl,
                      isAvailable: item.isInStock,
                      onTap: () {
                        if (!isStoreOpenInCatalog(ref, item.storeId)) {
                          showShopClosedSnackBar(context);
                          return;
                        }
                        showProductDetailsBottomSheet(
                          context: context,
                          ref: ref,
                          item: StoreMenuProduct.fromSearchProduct(item),
                          storeId: item.storeId,
                          storeName: item.storeName,
                        );
                      },
                      onAddToCart: () => addProductToCart(context, ref, item),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}
