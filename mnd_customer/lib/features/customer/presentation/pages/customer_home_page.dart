import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_page_background.dart';
import 'package:mnd_delivery_app/core/widgets/responsive_layout.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_banners_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/home_recommended_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/customer_home_header.dart';
import 'package:mnd_delivery_app/features/offers/presentation/providers/customer_offers_provider.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/add_to_home_screen_banner.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_category_rail.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_dispatch_hero.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_nearby_shops_section.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_recommended_section.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_search_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/floating_glass_nav_bar.dart';

class CustomerHomePage extends ConsumerWidget {
  const CustomerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ResponsiveLayout(
      mobile: _CustomerHomeContent(horizontalPadding: AppSpacing.md),
      tablet: _CustomerHomeContent(horizontalPadding: AppSpacing.xl),
    );
  }
}

class _CustomerHomeContent extends ConsumerWidget {
  const _CustomerHomeContent({required this.horizontalPadding});

  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double bottomClearance = floatingNavTotalHeight(context);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const HomePageBackground(),
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(customerBannersProvider);
            ref.invalidate(homeNearbyStoresStreamProvider);
            ref.invalidate(homeFeedProductsStreamProvider);
            ref.invalidate(customerOrdersStreamProvider);
            ref.invalidate(customerLiveOffersProvider);
            ref.invalidate(homeRecommendSessionSeedProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: <Widget>[
            SliverToBoxAdapter(
              child: CustomerHomeHeaderSection(
                horizontalPadding: horizontalPadding,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.xs,
                horizontalPadding,
                bottomClearance,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    const AddToHomeScreenBanner(),
                    const HomeSearchBar(),
                    const SizedBox(height: AppSpacing.sm),
                    const HomeCategoryRail(),
                    const SizedBox(height: AppSpacing.md),
                    const HomeDispatchHero(),
                    const SizedBox(height: AppSpacing.md),
                    const HomeRecommendedSection(),
                    const SizedBox(height: AppSpacing.md),
                    const HomeNearbyShopsSection(),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ],
    );
  }
}
