import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_page_background.dart';
import 'package:mnd_delivery_app/core/widgets/responsive_layout.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/customer_home_header.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/floating_glass_nav_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_category_rail.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_flash_deals_section.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_hero_carousel.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_nearby_shops_section.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_recently_ordered_section.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_recommended_section.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_search_bar.dart';

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

class _CustomerHomeContent extends ConsumerStatefulWidget {
  const _CustomerHomeContent({required this.horizontalPadding});

  final double horizontalPadding;

  @override
  ConsumerState<_CustomerHomeContent> createState() => _CustomerHomeContentState();
}

class _CustomerHomeContentState extends ConsumerState<_CustomerHomeContent> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    setState(() => _scrollOffset = _scrollController.offset);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomClearance = floatingNavTotalHeight(context) + AppSpacing.lg;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const HomePageBackground(),
        CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: CustomerHomeHeaderSection(
                horizontalPadding: widget.horizontalPadding,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                widget.horizontalPadding,
                0,
                widget.horizontalPadding,
                bottomClearance,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    HomeSearchBar(scrollOffset: _scrollOffset),
                    const SizedBox(height: AppSpacing.lg),
                    const HomeHeroCarousel(),
                    const SizedBox(height: AppSpacing.lg),
                    const HomeCategoryRail(),
                    const SizedBox(height: AppSpacing.lg),
                    const HomeRecommendedSection(),
                    const SizedBox(height: AppSpacing.lg),
                    const HomeNearbyShopsSection(),
                    const SizedBox(height: AppSpacing.lg),
                    const HomeFlashDealsSection(),
                    const SizedBox(height: AppSpacing.lg),
                    const HomeRecentlyOrderedSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
