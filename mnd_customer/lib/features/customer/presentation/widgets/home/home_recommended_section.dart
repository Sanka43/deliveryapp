import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/home_recommended_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/product_card.dart';
import 'package:mnd_delivery_app/features/store/presentation/widgets/product_details_bottom_sheet.dart';

class HomeRecommendedSection extends ConsumerWidget {
  const HomeRecommendedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RecommendedPick>> picksAsync =
        ref.watch(homeRecommendedPicksProvider);
    final AsyncValue<List<SearchStore>> storesAsync =
        ref.watch(homeNearbyStoresStreamProvider);

    return picksAsync.when(
      loading: () => HomeSectionEntrance(
        delay: const Duration(milliseconds: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            MndSectionHeader(
              title: 'Recommended for you',
              actionLabel: 'See all',
              onActionTap: () => context.push(AppRoutes.customerFood),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: ProductCard.homeListHeightCompact,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, __) => Container(
                  width: ProductCard.premiumWidth,
                  decoration: BoxDecoration(
                    color: AppColors.homeMutedFill,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      error: (Object error, _) => HomeSectionEntrance(
        delay: const Duration(milliseconds: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            MndSectionHeader(
              title: 'Recommended for you',
              actionLabel: 'See all',
              onActionTap: () => context.push(AppRoutes.customerFood),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 100,
              child: Center(child: Text(catalogLoadErrorMessage(error))),
            ),
          ],
        ),
      ),
      data: (List<RecommendedPick> picks) {
        if (picks.isEmpty) {
          return const SizedBox.shrink();
        }

        final Map<String, SearchStore> storeById = storesAsync.maybeWhen(
          data: (List<SearchStore> stores) => <String, SearchStore>{
            for (final SearchStore s in stores) s.id: s,
          },
          orElse: () => <String, SearchStore>{},
        );

        return HomeSectionEntrance(
          delay: const Duration(milliseconds: 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              MndSectionHeader(
                title: 'Recommended for you',
                actionLabel: 'See all',
                onActionTap: () => context.push(AppRoutes.customerFood),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: ProductCard.homeListHeightCompact,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: picks.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    final RecommendedPick pick = picks[index];
                    final SearchProduct item = pick.product;
                    final SearchStore? store = storeById[item.storeId];

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
                      onTap: item.storeId.isEmpty
                          ? null
                          : () {
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
                      onAddToCart: item.storeId.isEmpty
                          ? () {}
                          : () => addProductToCart(context, ref, item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
