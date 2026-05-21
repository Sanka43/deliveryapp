import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/features/auth/domain/rider_profile_document.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_registration_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_home_stats_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/widgets/rider_home_map.dart';
import 'package:mnd_rider/features/dashboard/presentation/widgets/rider_home_profile_header.dart';
import 'package:mnd_rider/features/dashboard/presentation/widgets/rider_home_stats_panel.dart';
import 'package:mnd_rider/features/dashboard/presentation/widgets/rider_pending_approval_panel.dart';

/// Map-first home dashboard with live stats and online toggle.
class RiderHomeDashboardPage extends ConsumerWidget {
  const RiderHomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RiderDashboardState dash = ref.watch(riderDashboardProvider);
    final RiderDashboardNotifier ctrl =
        ref.read(riderDashboardProvider.notifier);
    final RiderHomeStats stats = ref.watch(riderHomeStatsProvider);
    final RiderProfileDocument? profile =
        ref.watch(riderAuthProfileProvider).valueOrNull;
    final bool approved = ref.watch(riderIsApprovedToDriveProvider);
    final bool rejected = profile?.isRejected ?? false;

    ref.listen<AsyncValue<RiderProfileDocument?>>(riderAuthProfileProvider, (
      AsyncValue<RiderProfileDocument?>? _,
      AsyncValue<RiderProfileDocument?> next,
    ) {
      final RiderProfileDocument? doc = next.valueOrNull;
      if (doc == null) {
        return;
      }
      if (!doc.isApprovedToDrive && dash.isOnline) {
        ctrl.setOnline(false);
      } else if (doc.isApprovedToDrive) {
        ctrl.syncOnlineFromRemote(doc.online);
      }
    });

    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const RiderHomeMap(),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: RiderHomeProfileHeader(
                profile: profile,
                isOnline: approved && dash.isOnline,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: approved
                ? RiderHomeStatsPanel(
                    stats: stats,
                    isOnline: dash.isOnline,
                    onOnlineChanged: (bool value) async {
                      final String? err = await ctrl.setOnline(value);
                      if (err != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err)),
                        );
                      }
                    },
                  )
                : RiderPendingApprovalPanel(
                    profile: profile,
                    rejected: rejected,
                  ),
          ),
        ],
      ),
    );
  }
}
