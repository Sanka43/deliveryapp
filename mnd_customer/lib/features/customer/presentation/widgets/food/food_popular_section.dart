import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/food_catalog_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/product_card.dart';

class FoodPopularSection extends ConsumerWidget {
  const FoodPopularSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SearchProduct>> productsAsync =
        ref.watch(productsStreamProvider);
    final AsyncValue<List<SearchStore>> storesAsync = ref.watch(storesStreamProvider);
    final List<SearchProduct> popular = ref.watch(popularFoodProductsProvider);

    return HomeSectionEntrance(
      delay: const Duration(milliseconds: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const MndSectionHeader(title: 'Popular'),
          const SizedBox(height: AppSpacing.sm),
          productsAsync.when(
            loading: () => const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object error, _) => SizedBox(
              height: 80,
              child: Center(child: Text(catalogLoadErrorMessage(error))),
            ),
            data: (_) {
              if (popular.isEmpty) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: Text('No popular food items yet.')),
                );
              }

              final Map<String, SearchStore> storeById = storesAsync.maybeWhen(
                data: (List<SearchStore> stores) => <String, SearchStore>{
                  for (final SearchStore s in stores) s.id: s,
                },
                orElse: () => <String, SearchStore>{},
              );

              return SizedBox(
                height: ProductCard.homeListHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: popular.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    final SearchProduct item = popular[index];
                    final SearchStore? store = storeById[item.storeId];

                    if (item.storeId.isEmpty) {
                      return ProductCard(
                        premium: true,
                        productKey: item.lookupKey,
                        name: item.name,
                        storeName: item.storeName,
                        priceLabel: item.price,
                        imageUrl: item.imageUrl,
                        isAvailable: false,
                        onAddToCart: () {},
                      );
                    }

                    return ProductCard(
                      premium: true,
                      productKey: item.lookupKey,
                      name: item.name,
                      storeName: item.storeName,
                      etaLabel: store?.eta,
                      priceLabel: item.price,
                      imageUrl: item.imageUrl,
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
