import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/cart/presentation/widgets/floating_cart_summary_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/floating_glass_nav_bar.dart';

/// Bottom navigation shell: Home · Search · Orders · Profile.
class CustomerShellPage extends ConsumerWidget {
  const CustomerShellPage({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CartState cart = ref.watch(cartProvider);
    final bool showFloatingCart = !cart.isEmpty;
    final double navHeight = floatingNavTotalHeight(context);
    const double cartBarHeight = 72;

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(
              bottom: showFloatingCart ? cartBarHeight + 8 : 0,
            ),
            child: navigationShell,
          ),
          if (showFloatingCart)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: navHeight + 4,
              child: FloatingCartSummaryBar(
                onViewCart: () => context.push(AppRoutes.customerCart),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingGlassNavBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
            ),
          ),
        ],
      ),
    );
  }
}
