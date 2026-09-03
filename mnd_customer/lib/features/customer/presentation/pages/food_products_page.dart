import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/food/food_nearby_shops_section.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/food/food_page_search_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/food/food_popular_section.dart';

class FoodProductsPage extends ConsumerWidget {
  const FoodProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double bottomClearance =
        MediaQuery.paddingOf(context).bottom + AppSpacing.lg;

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(
        title: 'Food',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.customer);
            }
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(browseStoresStreamProvider);
          ref.invalidate(browseProductsStreamProvider);
        },
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            bottomClearance,
          ),
          children: const <Widget>[
            FoodPageSearchBar(),
            SizedBox(height: AppSpacing.md),
            FoodPopularSection(),
            SizedBox(height: AppSpacing.md),
            FoodNearbyShopsSection(),
          ],
        ),
      ),
    );
  }
}
