import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/features/rides/data/ride_directions_service.dart';
import 'package:mnd_delivery_app/features/rides/data/rides_repository.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/online_ride_rider.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_place.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_trip.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/ride_route_provider.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/rides_providers.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_map_markers.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_map_support.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_theme.dart';
import 'package:mnd_delivery_app/features/rides/presentation/widgets/rides_vehicle_icon.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';

/// Waiting for driver match — map of selected-vehicle online riders.
class RidesSearchingPage extends ConsumerStatefulWidget {
  const RidesSearchingPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<RidesSearchingPage> createState() => _RidesSearchingPageState();
}

class _RidesSearchingPageState extends ConsumerState<RidesSearchingPage> {
  bool _cancelling = false;
  bool _refinding = false;
  bool _markersReady = false;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    if (isRidesMapSupported()) {
      RidesMapMarkers.ensureLoaded().then((_) {
        if (mounted) {
          setState(() => _markersReady = true);
        }
      });
    } else {
      _markersReady = true;
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onClose() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.customerRides);
    }
  }

  Future<void> _cancel(String tripId) async {
    if (_cancelling || _refinding) {
      return;
    }
    setState(() => _cancelling = true);
    final String? err =
        await ref.read(ridesRepositoryProvider).cancelSearchingTrip(tripId);
    if (!mounted) {
      return;
    }
    setState(() => _cancelling = false);
    if (err != null) {
      showMndSnackBar(context, err);
      return;
    }
    context.go(AppRoutes.customerRides);
  }

  /// Cancel current search and start a new one with the same vehicle.
  Future<void> _refind(RideTrip trip) async {
    if (_refinding || _cancelling) {
      return;
    }
    setState(() => _refinding = true);
    final RidesRepository repo = ref.read(ridesRepositoryProvider);
    try {
      final String? cancelErr = await repo.cancelSearchingTrip(
        trip.id,
        reason: 'customer_refind',
      );
      if (cancelErr != null) {
        if (mounted) {
          showMndSnackBar(context, cancelErr, variant: MndSnackBarVariant.error);
        }
        return;
      }

      final List<RideFareQuote> quotes = await repo.quoteAllFares(
        pickup: trip.pickup,
        dropoff: trip.dropoff,
      );
      final String vehicle = trip.vehicleType.trim().toLowerCase();
      RideFareQuote? quote;
      for (final RideFareQuote q in quotes) {
        if (q.vehicleType.trim().toLowerCase() == vehicle &&
            q.quoteId.isNotEmpty) {
          quote = q;
          break;
        }
      }
      if (quote == null) {
        if (mounted) {
          showMndSnackBar(context, 'Could not refresh fare. Try again.', variant: MndSnackBarVariant.error);
        }
        return;
      }

      final String newTripId = await repo.confirmCashRide(
        quoteId: quote.quoteId,
        contactPhone: trip.contactPhone,
        driverNote: trip.driverNote ?? '',
        paymentMethod: trip.paymentMethod,
      );
      if (!mounted) {
        return;
      }
      if (newTripId.isEmpty) {
        showMndSnackBar(context, 'Could not start a new search.', variant: MndSnackBarVariant.error);
        return;
      }
      context.go(AppRoutes.customerRideTrip(newTripId));
    } catch (e) {
      if (mounted) {
        showMndSnackBar(
          context,
          userFacingError(e, fallback: 'Could not start a new search.'),
          variant: MndSnackBarVariant.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refinding = false);
      }
    }
  }

  Set<Marker> _buildMarkers({
    required RideTrip trip,
    required List<OnlineRideRider> riders,
    required RideVehicleType vehicle,
  }) {
    final Set<Marker> markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(trip.pickup.lat, trip.pickup.lng),
        icon: RidesMapMarkers.pickup,
        zIndexInt: 2,
      ),
      Marker(
        markerId: const MarkerId('drop'),
        position: LatLng(trip.dropoff.lat, trip.dropoff.lng),
        icon: RidesMapMarkers.dropoff,
        zIndexInt: 2,
      ),
    };
    if (!_markersReady) {
      return markers;
    }
    final BitmapDescriptor icon = RidesMapMarkers.vehicle(vehicle);
    for (final OnlineRideRider r in riders) {
      markers.add(
        Marker(
          markerId: MarkerId('rider_${r.riderId}'),
          position: LatLng(r.latitude, r.longitude),
          icon: icon,
          rotation: r.heading ?? 0,
          flat: r.heading != null,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 1,
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RideTrip?> tripAsync =
        ref.watch(rideTripProvider(widget.tripId));

    ref.listen<AsyncValue<RideTrip?>>(rideTripProvider(widget.tripId), (
      AsyncValue<RideTrip?>? prev,
      AsyncValue<RideTrip?> next,
    ) {
      final RideTrip? trip = next.asData?.value;
      if (trip == null) {
        return;
      }
      if (trip.isTrackable || trip.needsOnlinePayment) {
        context.go(AppRoutes.customerRideTracking(trip.id));
      }
    });

    return Scaffold(
      backgroundColor: const Color(RidesColors.sheetNavyDeep),
      body: tripAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (Object e, StackTrace _) => _ErrorBody(
          message: userFacingError(
            e,
            fallback: 'Could not load this trip. Please try again.',
          ),
        ),
        data: (RideTrip? trip) {
          if (trip == null) {
            return const _ErrorBody(message: 'Trip not found');
          }
          final bool waitingPay =
              trip.status == RideConstants.statusDraftPayment;
          final bool searching = trip.status == RideConstants.statusSearching;
          final RideVehicleType vehicle =
              RideVehicleType.fromFirestore(trip.vehicleType) ??
                  RideVehicleType.bike;

          final String fleetKey = searching
              ? onlineRidersQueryKey(
                  vehicleType: trip.vehicleType,
                  lat: trip.pickup.lat,
                  lng: trip.pickup.lng,
                )
              : '';
          final List<OnlineRideRider> riders = searching
              ? (ref.watch(onlineRidersNearPickupProvider(fleetKey)).asData
                      ?.value ??
                  const <OnlineRideRider>[])
              : const <OnlineRideRider>[];

          final RideDrivingRoute? road = ref
              .watch(
                rideDrivingRouteProvider(
                  RideRouteKey(trip.pickup, trip.dropoff, trip.stops),
                ),
              )
              .asData
              ?.value;
          final List<LatLng> routePoints = roadRoutePoints(road);
          final Set<Polyline> polylines = <Polyline>{
            if (routePoints.length >= 2)
              Polyline(
                polylineId: const PolylineId('route'),
                color: Colors.black,
                width: 5,
                points: routePoints,
              ),
          };

          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: _SearchingMap(
                  trip: trip,
                  markers: _buildMarkers(
                    trip: trip,
                    riders: riders,
                    vehicle: vehicle,
                  ),
                  polylines: polylines,
                  onMapCreated: (GoogleMapController c) {
                    _mapController = c;
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        onPressed: _onClose,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _SearchingSheet(
                  trip: trip,
                  waitingPay: waitingPay,
                  searching: searching,
                  vehicle: vehicle,
                  cancelling: _cancelling,
                  refinding: _refinding,
                  onCancel: () => _cancel(trip.id),
                  onRefind: () => _refind(trip),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchingMap extends StatelessWidget {
  const _SearchingMap({
    required this.trip,
    required this.markers,
    required this.polylines,
    required this.onMapCreated,
  });

  final RideTrip trip;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final void Function(GoogleMapController) onMapCreated;

  @override
  Widget build(BuildContext context) {
    if (!isRidesMapSupported()) {
      return Container(
        color: const Color(0xFFE8EEF6),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Text(
          'Map preview is available on Android and iOS.',
          textAlign: TextAlign.center,
        ),
      );
    }
    final LatLng center = LatLng(
      (trip.pickup.lat + trip.dropoff.lat) / 2,
      (trip.pickup.lng + trip.dropoff.lng) / 2,
    );
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 12.5),
      markers: markers,
      polylines: polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: onMapCreated,
    );
  }
}

class _SearchingSheet extends StatefulWidget {
  const _SearchingSheet({
    required this.trip,
    required this.waitingPay,
    required this.searching,
    required this.vehicle,
    required this.cancelling,
    required this.refinding,
    required this.onCancel,
    required this.onRefind,
  });

  final RideTrip trip;
  final bool waitingPay;
  final bool searching;
  final RideVehicleType vehicle;
  final bool cancelling;
  final bool refinding;
  final VoidCallback onCancel;
  final VoidCallback onRefind;

  @override
  State<_SearchingSheet> createState() => _SearchingSheetState();
}

class _SearchingSheetState extends State<_SearchingSheet> {
  Timer? _ticker;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _SearchingSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id ||
        oldWidget.searching != widget.searching) {
      _syncTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (!widget.searching) {
      _elapsedSeconds = 0;
      return;
    }
    final DateTime anchor = widget.trip.createdAt ?? DateTime.now();
    _elapsedSeconds = _elapsedFrom(anchor);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _elapsedSeconds = _elapsedFrom(anchor));
    });
  }

  int _elapsedFrom(DateTime anchor) {
    final int seconds = DateTime.now().difference(anchor).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final _SearchPhase phase = _SearchPhase.fromElapsed(
      widget.searching ? _elapsedSeconds : 0,
    );
    final bool exhausted =
        widget.searching && phase == _SearchPhase.exhausted;
    final bool busy = widget.cancelling || widget.refinding;
    final String vehicleLabel = widget.vehicle.label;
    final bool waitingPay = widget.waitingPay;
    final bool searching = widget.searching;
    final RideTrip trip = widget.trip;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          RidesSheet.outerMargin,
          0,
          RidesSheet.outerMargin,
          RidesSheet.outerMargin,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                RidesSheet.cardPaddingH,
                RidesSheet.cardPaddingTop,
                RidesSheet.cardPaddingH,
                RidesSheet.cardPaddingBottom,
              ),
              decoration: BoxDecoration(
                color: const Color(RidesColors.sheetNavy),
                borderRadius: BorderRadius.circular(RidesSheet.cardRadius),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    phase.title(waitingPay: waitingPay),
                    textAlign: TextAlign.center,
                    style: textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    phase.subtitle(waitingPay: waitingPay),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: const Color(RidesColors.mutedOnNavy),
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (searching) ...<Widget>[
                    const SizedBox(height: 8),
                    _SearchStepProgress(
                      activeIndex: phase.progressIndex,
                      exhausted: exhausted,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          RidesVehicleIcon(
                            type: widget.vehicle,
                            size: RidesSheet.actionIconSize,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$vehicleLabel · LKR ${trip.estimatedFareLkr}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _RouteCard(
                    pickup: trip.pickup.label,
                    dropoff: trip.dropoff.label,
                  ),
                ],
              ),
            ),
            if (searching || waitingPay) ...<Widget>[
              const SizedBox(height: RidesSheet.cardGap),
              if (searching && exhausted) ...<Widget>[
                SizedBox(
                  width: double.infinity,
                  height: RidesSheet.primaryButtonHeight,
                  child: FilledButton(
                    onPressed: busy ? null : widget.onRefind,
                    style: FilledButton.styleFrom(
                      backgroundColor: RidesColors.accentBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          RidesColors.accentBlue
                              .withValues(alpha: 0.45),
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(RidesSheet.buttonRadius),
                      ),
                    ),
                    child: widget.refinding
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white70,
                            ),
                          )
                        : Text(
                            'Refind',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: RidesSheet.cardGap),
              ],
              SizedBox(
                width: double.infinity,
                height: RidesSheet.primaryButtonHeight,
                child: FilledButton(
                  onPressed: busy ? null : widget.onCancel,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(RidesColors.sheetNavyDeep),
                    disabledBackgroundColor:
                        const Color(RidesColors.sheetNavyDeep)
                            .withValues(alpha: 0.55),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white54,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(RidesSheet.buttonRadius),
                    ),
                  ),
                  child: widget.cancelling
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white70,
                          ),
                        )
                      : Text(
                          'Cancel ride',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _SearchPhase {
  step1,
  step2,
  step3,
  exhausted;

  static _SearchPhase fromElapsed(int elapsedSeconds) {
    final int step = elapsedSeconds ~/ RideConstants.searchStepSeconds;
    if (step <= 0) {
      return _SearchPhase.step1;
    }
    if (step == 1) {
      return _SearchPhase.step2;
    }
    if (step == 2) {
      return _SearchPhase.step3;
    }
    return _SearchPhase.exhausted;
  }

  int get progressIndex => switch (this) {
        _SearchPhase.step1 => 0,
        _SearchPhase.step2 => 1,
        _SearchPhase.step3 => 2,
        _SearchPhase.exhausted => RideConstants.searchStepCount,
      };

  String title({required bool waitingPay}) {
    if (waitingPay) {
      return 'Confirming your ride…';
    }
    return switch (this) {
      _SearchPhase.step1 => 'Finding a nearby driver',
      _SearchPhase.step2 => 'Expanding your search',
      _SearchPhase.step3 => 'Still looking for a driver',
      _SearchPhase.exhausted => 'No drivers nearby',
    };
  }

  String subtitle({required bool waitingPay}) {
    if (waitingPay) {
      return 'Setting up your booking — this usually takes a moment.';
    }
    return switch (this) {
      _SearchPhase.step1 =>
        'Hang tight — matching the best driver for you.',
      _SearchPhase.step2 =>
        'Looking a bit farther for available drivers.',
      _SearchPhase.step3 =>
        'Almost there — checking more nearby riders.',
      _SearchPhase.exhausted =>
        'No drivers nearby yet. Tap Refind to search again.',
    };
  }
}

class _SearchStepProgress extends StatefulWidget {
  const _SearchStepProgress({
    required this.activeIndex,
    required this.exhausted,
  });

  final int activeIndex;
  final bool exhausted;

  @override
  State<_SearchStepProgress> createState() => _SearchStepProgressState();
}

class _SearchStepProgressState extends State<_SearchStepProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncFill();
  }

  @override
  void didUpdateWidget(covariant _SearchStepProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exhausted != widget.exhausted ||
        oldWidget.activeIndex != widget.activeIndex) {
      _syncFill(restart: oldWidget.activeIndex != widget.activeIndex);
    }
  }

  void _syncFill({bool restart = false}) {
    if (widget.exhausted) {
      _fill.stop();
      _fill.value = 1;
      return;
    }
    if (restart || !_fill.isAnimating) {
      _fill
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color accent = RidesColors.accentBlue;
    const Color dim = Color(0x2EFFFFFF);
    const double barW = 22;
    const double barH = 3;

    return AnimatedBuilder(
      animation: _fill,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOut.transform(_fill.value);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(RideConstants.searchStepCount, (
            int i,
          ) {
            final bool completed = widget.exhausted || i < widget.activeIndex;
            final bool isActive =
                !widget.exhausted && i == widget.activeIndex;
            final double fillAmount =
                completed ? 1.0 : (isActive ? t : 0.0);

            return Container(
              width: barW,
              height: barH,
              margin: EdgeInsets.only(
                right: i < RideConstants.searchStepCount - 1 ? 5 : 0,
              ),
              decoration: BoxDecoration(
                color: dim,
                borderRadius: BorderRadius.circular(3),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fillAmount.clamp(0.0, 1.0),
                heightFactor: 1,
                alignment: Alignment.centerLeft,
                child: const ColoredBox(color: accent),
              ),
            );
          }),
        );
      },
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.pickup,
    required this.dropoff,
  });

  final String pickup;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(RidesSheet.buttonRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: <Widget>[
          _RouteRow(
            pill: 'Pick-up',
            pillColor: const Color(RidesColors.pickupGreen),
            text: pickup,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 1.5,
                height: 8,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: Colors.white24,
              ),
            ),
          ),
          _RouteRow(
            pill: 'Drop-off',
            pillColor: const Color(RidesColors.dropoffRed),
            text: dropoff,
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.pill,
    required this.pillColor,
    required this.text,
  });

  final String pill;
  final Color pillColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: pillColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                pill,
                style: textTheme.labelSmall?.copyWith(
                  color: pillColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.15,
                ),
              ),
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
        ),
      ),
    );
  }
}
