import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/food_catalog_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/mnd_shop_card.dart';

const int _kMaxNearbyFoodShops = 5;

class FoodNearbyShopsSection extends ConsumerWidget {
  const FoodNearbyShopsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SearchStore>> async = ref.watch(storesStreamProvider);
    final List<SearchStore> foodStores = ref.watch(foodStoresProvider);

    return HomeSectionEntrance(
      delay: const Duration(milliseconds: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const MndSectionHeader(title: 'Nearby shops'),
          const SizedBox(height: AppSpacing.sm),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object error, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(catalogLoadErrorMessage(error)),
            ),
            data: (_) {
              if (foodStores.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('No food shops nearby yet.'),
                );
              }
              final List<SearchStore> slice = foodStores.length > _kMaxNearbyFoodShops
                  ? foodStores.sublist(0, _kMaxNearbyFoodShops)
                  : foodStores;
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: slice.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (BuildContext context, int index) {
                  final SearchStore store = slice[index];
                  return MndShopCard(
                    store: store,
                    onTap: () => openStoreDetails(context, store),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
