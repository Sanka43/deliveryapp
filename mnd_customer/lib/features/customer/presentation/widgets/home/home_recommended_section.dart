import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/product_card.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';

class HomeRecommendedSection extends ConsumerWidget {
  const HomeRecommendedSection({super.key});

  List<SearchProduct> _rankProducts(
    List<SearchProduct> products,
    List<CustomerOrderSummary> orders,
  ) {
    final Set<String> preferredStores = orders
        .where((CustomerOrderSummary o) => o.statusRaw == 'delivered')
        .take(2)
        .map((CustomerOrderSummary o) => o.storeName.toLowerCase())
        .toSet();

    final List<SearchProduct> boosted = <SearchProduct>[];
    final List<SearchProduct> rest = <SearchProduct>[];

    for (final SearchProduct p in products) {
      if (preferredStores.contains(p.storeName.toLowerCase())) {
        boosted.add(p);
      } else {
        rest.add(p);
      }
    }

    final List<SearchProduct> merged = <SearchProduct>[...boosted, ...rest];
    return merged.length > 12 ? merged.sublist(0, 12) : merged;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SearchProduct>> productsAsync =
        ref.watch(productsStreamProvider);
    final AsyncValue<List<SearchStore>> storesAsync = ref.watch(storesStreamProvider);
    final List<CustomerOrderSummary> orders =
        ref.watch(customerOrdersStreamProvider).asData?.value ?? const <CustomerOrderSummary>[];

    return HomeSectionEntrance(
      delay: const Duration(milliseconds: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          productsAsync.when(
            loading: () => const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object error, _) => SizedBox(
              height: 100,
              child: Center(child: Text(catalogLoadErrorMessage(error))),
            ),
            data: (List<SearchProduct> products) {
              if (products.isEmpty) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: Text('No products available yet.')),
                );
              }

              final Map<String, SearchStore> storeById = storesAsync.maybeWhen(
                data: (List<SearchStore> stores) => <String, SearchStore>{
                  for (final SearchStore s in stores) s.id: s,
                },
                orElse: () => <String, SearchStore>{},
              );

              final List<SearchProduct> slice = _rankProducts(products, orders);

              return SizedBox(
                height: ProductCard.homeListHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: slice.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    final SearchProduct item = slice[index];
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
