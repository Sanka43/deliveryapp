import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/services/maps/rider_maps_helper.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/auth/domain/rider_profile_document.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_registration_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_home_stats_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_map_location_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/widgets/rider_home_map.dart';
import 'package:mnd_rider/features/dashboard/presentation/widgets/rider_home_profile_header.dart';
import 'package:mnd_rider/features/dashboard/presentation/widgets/rider_home_stats_panel.dart';
import 'package:mnd_rider/features/dashboard/presentation/widgets/rider_pending_approval_panel.dart';
import 'package:mnd_rider/features/earnings/presentation/widgets/rider_cash_hold_banner.dart';
import 'package:mnd_rider/features/shell/presentation/widgets/rider_floating_nav_bar.dart';

/// Map-first home — full-bleed map with floating earnings + online controls.
class RiderHomeDashboardPage extends ConsumerStatefulWidget {
  const RiderHomeDashboardPage({super.key});

  @override
  ConsumerState<RiderHomeDashboardPage> createState() =>
      _RiderHomeDashboardPageState();
}

class _RiderHomeDashboardPageState
    extends ConsumerState<RiderHomeDashboardPage> {
  GoogleMapController? _mapController;

  Future<void> _recenter() async {
    final LatLng? pos = ref.read(riderMapLocationProvider).valueOrNull?.latLng;
    if (_mapController == null || pos == null) {
      return;
    }
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        RiderMapsHelper.cameraFor(pos, zoom: 15.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final RiderDashboardState dash = ref.watch(riderDashboardProvider);
    final RiderDashboardNotifier ctrl =
        ref.read(riderDashboardProvider.notifier);
    final RiderHomeStats stats = ref.watch(riderHomeStatsProvider);
    final RiderProfileDocument? profile =
        ref.watch(riderAuthProfileProvider).valueOrNull;
    final bool approved = ref.watch(riderIsApprovedToDriveProvider);
    final bool rejected = profile?.isRejected ?? false;
    final MediaQueryData mq = MediaQuery.of(context);
    final double topPad = mq.padding.top + 64;
    final double navInset = riderFloatingNavTotalHeight(context);
    // Dock sits above floating nav; map padding leaves room for white panel + pill.
    final double bottomPad = (approved ? 170 : 200) + navInset;

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
      backgroundColor: cs.surfaceContainerLowest,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RiderHomeMap(
            topPadding: topPad,
            bottomPadding: bottomPad,
            vehicleType: profile?.vehicleType,
            onControllerReady: (GoogleMapController c) {
              _mapController = c;
            },
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    RiderHomeProfileHeader(
                      isOnline: approved && dash.isOnline,
                      todayEarningsLkr: stats.todayEarningsLkr,
                      onOnlineChanged: approved
                          ? (bool value) async {
                              final String? err = await ctrl.setOnline(value);
                              if (err != null && context.mounted) {
                                showRiderSnackBar(context, err);
                              }
                            }
                          : null,
                    ),
                    const RiderCashHoldBanner(
                      margin: EdgeInsets.only(top: 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: bottomPad + 8,
            child: _RecenterFab(onPressed: _recenter),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: navInset),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (Widget child, Animation<double> anim) =>
                    FadeTransition(
                  opacity: anim,
                  child: SizeTransition(
                    sizeFactor: anim,
                    alignment: const Alignment(-1.0, -1.0),
                    child: child,
                  ),
                ),
                child: approved
                    ? RiderHomeStatsPanel(
                        key: const ValueKey<String>('stats'),
                        stats: stats,
                        isOnline: dash.isOnline,
                      )
                    : RiderPendingApprovalPanel(
                        key: const ValueKey<String>('pending'),
                        profile: profile,
                        rejected: rejected,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecenterFab extends StatelessWidget {
  const _RecenterFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            Icons.my_location_rounded,
            color: cs.onSurface,
            size: 24,
          ),
        ),
      ),
    );
  }
}
