import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/services/firebase_messaging_service.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/cart/presentation/widgets/floating_cart_summary_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/floating_glass_nav_bar.dart';

/// Customer shell with floating bottom nav.
class CustomerShellPage extends ConsumerStatefulWidget {
  const CustomerShellPage({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<CustomerShellPage> createState() => _CustomerShellPageState();
}

class _CustomerShellPageState extends ConsumerState<CustomerShellPage> {
  static bool _askedNotificationPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_askedNotificationPermission || !mounted) {
        return;
      }
      _askedNotificationPermission = true;
      // After auth / guest browse — never on splash/login.
      FirebaseMessagingService.requestPermissionAfterFirstFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final CartState cart = ref.watch(cartProvider);
    final bool showFloatingCart = !cart.isEmpty;
    final double navHeight = floatingNavTotalHeight(context);
    final StatefulNavigationShell navigationShell = widget.navigationShell;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          navigationShell,
          if (showFloatingCart)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: navHeight,
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
