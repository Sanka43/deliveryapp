import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/mnd_shop_card.dart';

const int _kMaxHomeShops = 6;

class HomeNearbyShopsSection extends ConsumerWidget {
  const HomeNearbyShopsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SearchStore>> async =
        ref.watch(homeNearbyStoresStreamProvider);

    return async.when(
      loading: () => HomeSectionEntrance(
        delay: const Duration(milliseconds: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            MndSectionHeader(
              title: 'Popular Near You',
              actionLabel: 'See all',
              onActionTap: () => context.push(AppRoutes.customerShops),
            ),
            const SizedBox(height: AppSpacing.sm),
            Column(
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
          ],
        ),
      ),
      error: (Object error, _) => HomeSectionEntrance(
        delay: const Duration(milliseconds: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            MndSectionHeader(
              title: 'Popular Near You',
              actionLabel: 'See all',
              onActionTap: () => context.push(AppRoutes.customerShops),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(catalogLoadErrorMessage(error)),
            ),
          ],
        ),
      ),
      data: (List<SearchStore> stores) {
        if (stores.isEmpty) {
          return const SizedBox.shrink();
        }

        final List<SearchStore> topRated = List<SearchStore>.from(stores)
          ..sort(
            (SearchStore a, SearchStore b) => b.rating.compareTo(a.rating),
          );
        final List<SearchStore> slice = topRated.length > _kMaxHomeShops
            ? topRated.sublist(0, _kMaxHomeShops)
            : topRated;

        return HomeSectionEntrance(
          delay: const Duration(milliseconds: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              MndSectionHeader(
                title: 'Popular Near You',
                actionLabel: 'See all',
                onActionTap: () => context.push(AppRoutes.customerShops),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListView.separated(
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
              ),
            ],
          ),
        );
      },
    );
  }
}
