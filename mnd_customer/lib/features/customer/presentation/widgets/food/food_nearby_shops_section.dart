import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
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
    final AsyncValue<List<SearchStore>> async =
        ref.watch(browseStoresStreamProvider);
    final List<SearchStore> foodStores = ref.watch(foodStoresProvider);

    return HomeSectionEntrance(
      delay: Duration.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const MndSectionHeader(title: 'Nearby Shops'),
          const SizedBox(height: AppSpacing.sm),
          async.when(
            loading: () => Column(
              children: List<Widget>.generate(
                2,
                (int i) => Padding(
                  padding: EdgeInsets.only(
                    bottom: i == 1 ? 0 : AppSpacing.sm,
                  ),
                  child: Container(
                    height: MndShopCardCompact.cardHeight,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius:
                          BorderRadius.circular(AppColors.cardRadiusMd),
                    ),
                  ),
                ),
              ),
            ),
            error: (Object error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                catalogLoadErrorMessage(error),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
            data: (_) {
              if (foodStores.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'No food shops nearby yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                );
              }
              final List<SearchStore> slice =
                  foodStores.length > _kMaxNearbyFoodShops
                      ? foodStores.sublist(0, _kMaxNearbyFoodShops)
                      : foodStores;
              return ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: slice.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int index) {
                  final SearchStore store = slice[index];
                  return MndShopCardCompact(
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
