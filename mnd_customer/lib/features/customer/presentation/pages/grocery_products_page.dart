import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/grocery_catalog_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/grocery/grocery_category_chips.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/grocery/grocery_nearby_shops_section.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/grocery/grocery_page_search_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/grocery/grocery_popular_section.dart';

class GroceryProductsPage extends ConsumerWidget {
  const GroceryProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double bottomClearance =
        MediaQuery.paddingOf(context).bottom + AppSpacing.lg;

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(
        title: 'Groceries',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
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
          ref.invalidate(groceryCategoryLabelsProvider);
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
            GroceryPageSearchBar(),
            SizedBox(height: AppSpacing.sm),
            GroceryCategoryChips(),
            SizedBox(height: AppSpacing.md),
            GroceryPopularSection(),
            SizedBox(height: AppSpacing.md),
            GroceryNearbyShopsSection(),
          ],
        ),
      ),
    );
  }
}
