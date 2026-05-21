import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_page_background.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/food/food_category_chips.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/food/food_nearby_shops_section.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/food/food_page_search_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/food/food_popular_section.dart';

class FoodProductsPage extends ConsumerWidget {
  const FoodProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const HomePageBackground(),
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.textPrimary,
                  onPressed: () => context.pop(),
                ),
                title: Text(
                  'Food',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      const FoodPageSearchBar(),
                      const SizedBox(height: AppSpacing.lg),
                      const FoodCategoryChips(),
                      const SizedBox(height: AppSpacing.lg),
                      const FoodPopularSection(),
                      const SizedBox(height: AppSpacing.lg),
                      const FoodNearbyShopsSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
