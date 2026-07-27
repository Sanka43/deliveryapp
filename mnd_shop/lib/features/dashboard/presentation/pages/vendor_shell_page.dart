import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/vendor_shell_tab_provider.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/dashboard/presentation/pages/vendor_analytics_tab_page.dart';
import 'package:mnd_shop/features/dashboard/presentation/pages/vendor_dashboard_page.dart';
import 'package:mnd_shop/features/orders/presentation/pages/vendor_orders_tab_page.dart';
import 'package:mnd_shop/features/products/presentation/pages/vendor_catalog_hub_page.dart';
import 'package:mnd_shop/features/dashboard/presentation/widgets/vendor_pill_bottom_nav.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_settings_page.dart';

/// Main authenticated shell: Home, Products, Orders, Analytics, Settings.
class VendorShellPage extends ConsumerWidget {
  const VendorShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int index = ref.watch(vendorShellTabIndexProvider);
    final bool isSinhala = Localizations.localeOf(context).languageCode == 'si';
    final List<VendorNavItem> navItems = <VendorNavItem>[
      VendorNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: isSinhala ? 'මුල් පිටුව' : 'Home',
      ),
      VendorNavItem(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        label: isSinhala ? 'නිෂ්පාදන' : 'Products',
      ),
      VendorNavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        label: isSinhala ? 'ඇණවුම්' : 'Orders',
      ),
      VendorNavItem(
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights,
        label: isSinhala ? 'විශ්ලේෂණ' : 'Analytics',
      ),
      VendorNavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: isSinhala ? 'සැකසුම්' : 'Settings',
      ),
    ];
    final bool useTabletLayout = vendorUsesTabletLayout(context);
    final Widget pages = IndexedStack(
      index: index,
      sizing: StackFit.expand,
      children: const <Widget>[
        VendorDashboardPage(),
        VendorCatalogHubPage(),
        VendorOrdersTabPage(),
        VendorAnalyticsTabPage(),
        VendorSettingsPage(),
      ],
    );

    return Scaffold(
      extendBody: !useTabletLayout,
      body: useTabletLayout
          ? Row(
              children: <Widget>[
                _VendorTabletRail(
                  currentIndex: index,
                  items: navItems,
                  onTap: (int i) {
                    ref.read(vendorShellTabIndexProvider.notifier).state = i;
                  },
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: pages),
              ],
            )
          : pages,
      bottomNavigationBar: useTabletLayout
          ? null
          : Material(
              type: MaterialType.transparency,
              color: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              child: VendorPillBottomNav(
                currentIndex: index,
                items: navItems,
                onTap: (int i) {
                  ref.read(vendorShellTabIndexProvider.notifier).state = i;
                },
              ),
            ),
    );
  }
}

class _VendorTabletRail extends StatelessWidget {
  const _VendorTabletRail({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<VendorNavItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool extended = MediaQuery.sizeOf(context).width >= 1100;
    return NavigationRail(
      selectedIndex: currentIndex,
      extended: extended,
      minWidth: 84,
      minExtendedWidth: 174,
      backgroundColor: theme.colorScheme.surface,
      indicatorColor: AppColors.navBarActiveChip,
      selectedIconTheme: const IconThemeData(
        color: AppColors.navBarActiveForeground,
      ),
      selectedLabelTextStyle: theme.textTheme.labelLarge?.copyWith(
        color: AppColors.textCharcoal,
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w700,
      ),
      onDestinationSelected: onTap,
      destinations: <NavigationRailDestination>[
        for (final VendorNavItem item in items)
          NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: Text(item.label),
          ),
      ],
    );
  }
}
