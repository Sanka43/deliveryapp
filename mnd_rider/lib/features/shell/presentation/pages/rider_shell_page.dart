import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/dashboard/presentation/pages/rider_home_dashboard_page.dart';
import 'package:mnd_rider/features/earnings/presentation/pages/rider_earnings_page.dart';
import 'package:mnd_rider/features/orders/presentation/pages/rider_orders_tab_page.dart';
import 'package:mnd_rider/features/profile/presentation/pages/rider_profile_page.dart';
import 'package:mnd_rider/features/shell/presentation/providers/rider_shell_tab_provider.dart';
import 'package:mnd_rider/features/shell/presentation/widgets/rider_pill_bottom_nav.dart';

class RiderShellPage extends ConsumerWidget {
  const RiderShellPage({super.key});

  static const List<RiderNavItem> _navItems = <RiderNavItem>[
    RiderNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    RiderNavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'Orders',
    ),
    RiderNavItem(
      icon: Icons.payments_outlined,
      activeIcon: Icons.payments,
      label: 'Earnings',
    ),
    RiderNavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int index = ref.watch(riderShellTabIndexProvider);

    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          IndexedStack(
            index: index,
            children: const <Widget>[
              RiderHomeDashboardPage(),
              RiderOrdersTabPage(),
              RiderEarningsPage(),
              RiderProfilePage(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RiderPillBottomNav(
              currentIndex: index,
              items: _navItems,
              onTap: (int i) {
                ref.read(riderShellTabIndexProvider.notifier).state = i;
              },
            ),
          ),
        ],
      ),
    );
  }
}
