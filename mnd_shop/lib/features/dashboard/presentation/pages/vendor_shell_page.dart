import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/vendor_shell_tab_provider.dart';
import 'package:mnd_shop/features/dashboard/presentation/pages/vendor_analytics_tab_page.dart';
import 'package:mnd_shop/features/dashboard/presentation/pages/vendor_dashboard_page.dart';
import 'package:mnd_shop/features/orders/presentation/pages/vendor_orders_tab_page.dart';
import 'package:mnd_shop/features/products/presentation/pages/vendor_catalog_hub_page.dart';
import 'package:mnd_shop/features/dashboard/presentation/widgets/vendor_pill_bottom_nav.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_settings_page.dart';

/// Main authenticated shell: Home, Product, Orders, Analytics, Setting.
class VendorShellPage extends ConsumerWidget {
  const VendorShellPage({super.key});

  static const List<VendorNavItem> _navItems = <VendorNavItem>[
    VendorNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    VendorNavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      label: 'Product',
    ),
    VendorNavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'Orders',
    ),
    VendorNavItem(
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights,
      label: 'Analytics',
    ),
    VendorNavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Setting',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int index = ref.watch(vendorShellTabIndexProvider);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: index,
        sizing: StackFit.expand,
        children: const <Widget>[
          VendorDashboardPage(),
          VendorCatalogHubPage(),
          VendorOrdersTabPage(),
          VendorAnalyticsTabPage(),
          VendorSettingsPage(),
        ],
      ),
      bottomNavigationBar: Material(
        type: MaterialType.transparency,
        color: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        child: VendorPillBottomNav(
          currentIndex: index,
          items: _navItems,
          onTap: (int i) {
            ref.read(vendorShellTabIndexProvider.notifier).state = i;
          },
        ),
      ),
    );
  }
}
