import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_empty_state.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/home_recent_searches_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/floating_glass_nav_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/product_card.dart';

class CustomerFavoritesPage extends ConsumerWidget {
  const CustomerFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> favKeys = ref.watch(productFavoritesProvider);
    final AsyncValue<List<SearchProduct>> productsAsync =
        ref.watch(favoriteProductsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(title: 'Favorites', implyLeading: false),
      body: favKeys.isEmpty
          ? const MndEmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'No favorites yet',
              subtitle:
                  'Tap the heart on a product to save it here for quick access.',
            )
          : productsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator.adaptive(),
              ),
              error: (Object error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(catalogLoadErrorMessage(error)),
                ),
              ),
              data: (List<SearchProduct> favorites) {
                if (favorites.isEmpty) {
                  return const MndEmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'Favorites unavailable',
                    subtitle:
                        'Saved items are no longer in the catalog. Remove and re-add from a shop menu.',
                  );
                }

                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    floatingNavTotalHeight(context),
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: ProductCard.gridChildAspectRatio,
                  ),
                  itemCount: favorites.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SearchProduct item = favorites[index];
                    return ProductCard(
                      productKey: item.lookupKey,
                      name: item.name,
                      imageUrl: item.imageUrl,
                      priceLabel: item.price,
                      storeName: item.storeName,
                      isAvailable: item.isInStock,
                      onTap: () => openStoreMenuForProductChoice(
                        context,
                        ref,
                        item,
                      ),
                      onAddToCart: () => addProductToCart(context, ref, item),
                    );
                  },
                );
              },
            ),
    );
  }
}
