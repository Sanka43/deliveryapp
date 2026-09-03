import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/dashboard/presentation/pages/rider_home_dashboard_page.dart';
import 'package:mnd_rider/features/earnings/presentation/pages/rider_earnings_page.dart';
import 'package:mnd_rider/features/jobs/presentation/pages/rider_jobs_tab_page.dart';
import 'package:mnd_rider/features/profile/presentation/pages/rider_profile_page.dart';
import 'package:mnd_rider/features/shell/presentation/providers/rider_shell_tab_provider.dart';
import 'package:mnd_rider/features/shell/presentation/widgets/rider_floating_nav_bar.dart';

class RiderShellPage extends ConsumerWidget {
  const RiderShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int index = ref.watch(riderShellTabIndexProvider);
    final bool navVisible = ref.watch(riderShellNavVisibleProvider);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: cs.surfaceContainerLowest,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Full-bleed so tab content shows through gaps around the floating pill.
            IndexedStack(
              index: index,
              children: const <Widget>[
                RiderHomeDashboardPage(),
                RiderJobsTabPage(),
                RiderEarningsPage(),
                RiderProfilePage(),
              ],
            ),
            if (navVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: RiderFloatingNavBar(
                  selectedIndex: index,
                  onDestinationSelected: (int i) {
                    ref.read(riderShellTabIndexProvider.notifier).state = i;
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
