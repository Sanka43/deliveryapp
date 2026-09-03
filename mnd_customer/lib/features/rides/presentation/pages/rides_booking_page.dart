import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/widgets/map_unavailable_banner.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/rides/data/ride_directions_service.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_place.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_trip.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/presentation/pages/rides_place_picker_page.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/ride_quotes_provider.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/ride_route_provider.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/rides_providers.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_map_markers.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_map_support.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_theme.dart';
import 'package:mnd_delivery_app/features/rides/presentation/widgets/rides_map_controls.dart';

/// Screen 1 — pickup / drop-off overview map.
class RidesBookingPage extends ConsumerStatefulWidget {
  const RidesBookingPage({super.key});

  @override
  ConsumerState<RidesBookingPage> createState() => _RidesBookingPageState();
}

class _RidesBookingPageState extends ConsumerState<RidesBookingPage> {
  GoogleMapController? _mapController;
  bool _bootstrapped = false;
  bool _didRedirectActive = false;
  bool _locating = false;
  bool _markersReady = false;
  double _zoom = 14;

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

  Future<void> _bootstrapPickup() async {
    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;
    final RideBookingDraft draft = ref.read(rideBookingDraftProvider);
    if (draft.pickup != null) {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(draft.pickup!.lat, draft.pickup!.lng),
          15,
        ),
      );
      return;
    }
    // Fast path: last-known / medium GPS → pin immediately, label async.
    final Position? pos = await resolveCurrentPosition();
    if (!mounted || pos == null) {
      return;
    }
    final RidePlace provisional = ridePlaceFromPosition(pos);
    ref.read(rideBookingDraftProvider.notifier).setPickup(provisional);
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(provisional.lat, provisional.lng), 15),
    );
    if (mounted) {
      setState(() => _zoom = 15);
    }
    final RidePlace labeled = await reverseGeocodeRidePlace(
      LatLng(pos.latitude, pos.longitude),
    );
    if (!mounted) {
      return;
    }
    final RidePlace? current = ref.read(rideBookingDraftProvider).pickup;
    if (current != null &&
        (current.lat - labeled.lat).abs() < 0.0002 &&
        (current.lng - labeled.lng).abs() < 0.0002) {
      ref.read(rideBookingDraftProvider.notifier).setPickup(labeled);
    }
  }

  Future<void> _goToLiveLocation() async {
    setState(() => _locating = true);
    try {
      final PlaceResolveResult result = await resolveCurrentPlaceResult();
      final RidePlace? place = result.place;
      if (!mounted) {
        return;
      }
      if (place == null) {
        showMndSnackBar(
          context,
          locationUnavailableMessage(
            permissionDenied: result.permissionDenied,
          ),
          variant: MndSnackBarVariant.warning,
          duration: const Duration(seconds: 6),
        );
        return;
      }
      setState(() => _zoom = 16);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(place.lat, place.lng), 16),
      );
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _zoomBy(double delta) async {
    final double next = (_zoom + delta).clamp(3.0, 20.0);
    setState(() => _zoom = next);
    await _mapController?.animateCamera(CameraUpdate.zoomTo(next));
  }

  Future<void> _openPickupPicker() async {
    final RideBookingDraft draft = ref.read(rideBookingDraftProvider);
    final RidePlace? place = await RidesPlacePickerPage.open(
      context,
      mode: RidesPlacePickerMode.pickup,
      initial: draft.pickup,
    );
    if (place == null || !mounted) {
      return;
    }
    ref.read(rideBookingDraftProvider.notifier).setPickup(place);
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(place.lat, place.lng), 15),
    );
  }

  Future<void> _openDropoffPicker() async {
    final RideBookingDraft draft = ref.read(rideBookingDraftProvider);
    final RidePlace? place = await RidesPlacePickerPage.open(
      context,
      mode: RidesPlacePickerMode.dropoff,
      initial: draft.dropoff ?? draft.pickup,
    );
    if (place == null || !mounted) {
      return;
    }
    ref.read(rideBookingDraftProvider.notifier).setDropoff(place);
    await _settleThenFitRoute();
  }

  Future<void> _openStopPicker({int? index}) async {
    final RideBookingDraft draft = ref.read(rideBookingDraftProvider);
    final RidePlace? existing =
        index != null && index < draft.stops.length ? draft.stops[index] : null;
    final RidePlace? place = await RidesPlacePickerPage.open(
      context,
      mode: RidesPlacePickerMode.stop,
      initial: existing ?? draft.dropoff ?? draft.pickup,
    );
    if (place == null || !mounted) {
      return;
    }
    final RideBookingDraftNotifier notifier =
        ref.read(rideBookingDraftProvider.notifier);
    final String? error = index != null
        ? notifier.updateStopAt(index, place)
        : notifier.addStop(place);
    if (error != null) {
      if (mounted) {
        showMndSnackBar(context, error, variant: MndSnackBarVariant.warning);
      }
      return;
    }
    await _settleThenFitRoute();
  }

  void _removeStop(int index) {
    ref.read(rideBookingDraftProvider.notifier).removeStopAt(index);
  }

  /// The picker is a full-screen route pushed on top of this page; popping
  /// it starts a slide-transition that keeps resizing this page's GoogleMap
  /// element for a couple hundred ms. `newLatLngBounds` fits a pixel padding
  /// against the map's *current* viewport size, so calling it immediately —
  /// while the element is still mid-transition and reporting a transitional
  /// size — can hand Google Maps a distorted fit and leave the camera
  /// zoomed out to fit a bogus box instead of the actual pickup/drop-off
  /// pins. A plain zoom-to-point (see `_openPickupPicker`) isn't
  /// viewport-size sensitive so it doesn't hit this; bounds-fitting does.
  /// Waiting for the pop transition to finish avoids it.
  Future<void> _settleThenFitRoute() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) {
      return;
    }
    await _fitRouteIfPossible();
  }

  Future<void> _fitRouteIfPossible() async {
    final RideBookingDraft draft = ref.read(rideBookingDraftProvider);
    if (draft.pickup == null ||
        draft.dropoff == null ||
        _mapController == null) {
      return;
    }
    final List<LatLng> points = <LatLng>[
      LatLng(draft.pickup!.lat, draft.pickup!.lng),
      for (final RidePlace stop in draft.stops) LatLng(stop.lat, stop.lng),
      LatLng(draft.dropoff!.lat, draft.dropoff!.lng),
    ];
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;
    for (final LatLng p in points) {
      south = south < p.latitude ? south : p.latitude;
      north = north > p.latitude ? north : p.latitude;
      west = west < p.longitude ? west : p.longitude;
      east = east > p.longitude ? east : p.longitude;
    }
    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 72),
      );
    } catch (_) {
      // Bounds-fit failed/misbehaved (e.g. a transitional viewport size on
      // web) — fall back to a plain centered zoom so the camera never gets
      // stuck showing a huge bogus area instead of the actual pins.
      final LatLng mid = LatLng((south + north) / 2, (west + east) / 2);
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(mid, 12),
      );
    }
  }

  void _onViewVehicle() {
    final RideBookingDraft draft = ref.read(rideBookingDraftProvider);
    if (!draft.canViewVehicles) {
      showMndSnackBar(context, 'Choose pickup and drop-off first.',
          variant: MndSnackBarVariant.warning);
      return;
    }
    // Ensure fare prefetch is running before confirm opens — only once
    // signed in. `quoteRideFares` requires auth and throws unauthenticated
    // otherwise; the confirm page's own fare-quote fetch already shows a
    // "Sign in to get a fare quote" prompt for guests.
    final bool signedIn = !ref.read(guestBrowsingProvider) &&
        ref.read(firebaseAuthProvider).currentUser != null;
    final RideFareQuotesKey? key = draftFareQuotesKey(draft);
    if (signedIn && key != null) {
      ref.read(rideFareQuotesProvider(key));
    }
    context.push(AppRoutes.customerRidesVehicle);
  }

  void _maybeRedirectActive(RideTrip? trip) {
    if (_didRedirectActive || trip == null || !mounted) {
      return;
    }
    _didRedirectActive = true;
    if (trip.status == RideConstants.statusSearching ||
        trip.status == RideConstants.statusDraftPayment) {
      context.go(AppRoutes.customerRideTrip(trip.id));
    } else if (trip.isTrackable || trip.needsOnlinePayment) {
      context.go(AppRoutes.customerRideTracking(trip.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final RideBookingDraft draft = ref.watch(rideBookingDraftProvider);
    final AsyncValue<RideTrip?> active = ref.watch(activeRideTripProvider);
    final AsyncValue<RideTrip?> unpaidCompleted =
        ref.watch(unpaidCompletedRideTripProvider);
    final bool guest = ref.watch(guestBrowsingProvider);
    final bool signedOut = ref.watch(firebaseAuthProvider).currentUser == null;
    final bool showSignInBanner = guest || signedOut;
    // Prefetch server fares as soon as both pins exist (before confirm) —
    // only once signed in. `quoteRideFares` requires auth and throws
    // unauthenticated otherwise, which the map's error handling doesn't
    // recover from cleanly (route preview gets stuck). The route preview
    // itself (draftRideRouteProvider, below) doesn't need auth and still
    // shows for guests.
    if (!showSignInBanner) {
      ref.watch(draftRideFareQuotesProvider);
    }
    final double bottomSafe = MediaQuery.paddingOf(context).bottom;
    const double sheetBlock = 250;
    final double controlsBottom = sheetBlock + bottomSafe + 12;

    ref.listen<AsyncValue<RideTrip?>>(activeRideTripProvider, (
      AsyncValue<RideTrip?>? prev,
      AsyncValue<RideTrip?> next,
    ) {
      _maybeRedirectActive(next.asData?.value);
    });
    ref.listen<AsyncValue<RideTrip?>>(unpaidCompletedRideTripProvider, (
      AsyncValue<RideTrip?>? prev,
      AsyncValue<RideTrip?> next,
    ) {
      _maybeRedirectActive(next.asData?.value);
    });
    if (active.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeRedirectActive(active.asData?.value);
      });
    }
    if (unpaidCompleted.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeRedirectActive(unpaidCompleted.asData?.value);
      });
    }

    final LatLng initial = draft.pickup != null
        ? LatLng(draft.pickup!.lat, draft.pickup!.lng)
        : kRidesDefaultCenter;

    final Set<Marker> markers = <Marker>{
      if (draft.pickup != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(draft.pickup!.lat, draft.pickup!.lng),
          infoWindow: const InfoWindow(title: 'Pick up'),
          icon: _markersReady
              ? RidesMapMarkers.pickup
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
          anchor: const Offset(0.5, 1.0),
        ),
      if (draft.dropoff != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(draft.dropoff!.lat, draft.dropoff!.lng),
          infoWindow: const InfoWindow(title: 'Drop'),
          icon: _markersReady
              ? RidesMapMarkers.dropoff
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
          anchor: const Offset(0.5, 1.0),
        ),
      for (int i = 0; i < draft.stops.length; i++)
        Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(draft.stops[i].lat, draft.stops[i].lng),
          infoWindow: InfoWindow(title: 'Stop ${i + 1}'),
          icon: _markersReady
              ? RidesMapMarkers.stopAt(i)
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
          anchor: const Offset(0.5, 1.0),
        ),
    };

    final RideDrivingRoute? previewRoute =
        ref.watch(draftRideRouteProvider).asData?.value;
    final List<LatLng> previewPoints = roadRoutePoints(previewRoute);
    final Set<Polyline> polylines = <Polyline>{
      if (previewPoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('preview'),
          color: const Color(RidesColors.sheetNavy),
          width: 5,
          points: previewPoints,
        ),
    };

    final bool activeError = active.hasError;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          if (isRidesMapSupported())
            GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 14),
              onMapCreated: (GoogleMapController c) {
                _mapController = c;
                _bootstrapPickup();
              },
              onCameraMove: (CameraPosition position) {
                _zoom = position.zoom;
              },
              markers: markers,
              polylines: polylines,
              // Google's own blue-dot layer is redundant here — this screen
              // already has its own locate-me button (`_goToLiveLocation`,
              // via `RidesMapControls`) that resolves and centers on GPS
              // itself. On some mobile browsers a bad/huge `coords.accuracy`
              // reading makes Google's built-in accuracy circle render as a
              // giant overlay that, cropped to the viewport, shows as a
              // solid bar across the map — disabling the redundant layer
              // avoids that risk entirely instead of chasing the exact
              // trigger.
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            )
          else
            Container(
              color: AppColors.homeMutedFill,
              alignment: Alignment.center,
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Map preview is available on Android and iOS. Tap Pick-up / Drop-off to choose a place.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _RoundIconButton(
                        icon: Icons.arrow_back,
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRoutes.customer);
                          }
                        },
                      ),
                      const Spacer(),
                      _RoundIconButton(
                        icon: Icons.history,
                        onTap: () =>
                            context.push(AppRoutes.customerRidesHistory),
                      ),
                    ],
                  ),
                  if (showSignInBanner) ...<Widget>[
                    const SizedBox(height: 8),
                    SignInRequiredBanner(
                      message: 'Sign in to book rides and track your trips.',
                      redirectTo: AppRoutes.customerRides,
                    ),
                  ],
                  if (MapUnavailableBanner.shouldShow) ...<Widget>[
                    const SizedBox(height: 8),
                    const MapUnavailableBanner(),
                  ],
                ],
              ),
            ),
          ),
          if (isRidesMapSupported())
            RidesMapControls(
              bottomInset: controlsBottom,
              locating: _locating,
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
              onMyLocation: _goToLiveLocation,
            ),
          if (activeError)
            Positioned(
              left: 16,
              right: 72,
              bottom: controlsBottom + 8,
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => ref.invalidate(activeRideTripProvider),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            "Couldn't load your active ride. Tap to retry.",
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.refresh_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  RidesSheet.outerMargin,
                  0,
                  RidesSheet.outerMargin,
                  RidesSheet.outerMargin,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                        borderRadius:
                            BorderRadius.circular(RidesSheet.cardRadius),
                      ),
                      child: Column(
                        children: <Widget>[
                          _LocationRow(
                            pill: 'Pick-up',
                            pillColor: const Color(RidesColors.pickupGreen),
                            title: draft.pickup?.label ?? 'Set pickup',
                            hint: 'tap to choose on map',
                            onTap: _openPickupPicker,
                          ),
                          for (int i = 0;
                              i < draft.stops.length;
                              i++) ...<Widget>[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child:
                                  Divider(color: Color(0xFF1E3A6E), height: 1),
                            ),
                            _LocationRow(
                              pill: 'Stop ${i + 1}',
                              pillColor: const Color(RidesColors.stopAmber),
                              title: draft.stops[i].label,
                              hint: 'tap to change · or remove',
                              onTap: () => _openStopPicker(index: i),
                              onRemove: () => _removeStop(i),
                            ),
                          ],
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(color: Color(0xFF1E3A6E), height: 1),
                          ),
                          _LocationRow(
                            pill: 'Drop-off',
                            pillColor: const Color(RidesColors.dropoffRed),
                            title: draft.dropoff?.label ?? 'Where to?',
                            hint: 'tap to choose on map',
                            onTap: _openDropoffPicker,
                          ),
                          if (draft.stops.length < kMaxRideStops) ...<Widget>[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _openStopPicker(),
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 18,
                                  color: Color(RidesColors.stopAmber),
                                ),
                                label: Text(
                                  draft.stops.isEmpty
                                      ? 'Add a stop'
                                      : 'Add another stop',
                                  style: const TextStyle(
                                    color: Color(RidesColors.stopAmber),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  alignment: Alignment.centerLeft,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: RidesSheet.cardGap),
                    SizedBox(
                      width: double.infinity,
                      height: RidesSheet.primaryButtonHeight,
                      child: FilledButton(
                        onPressed:
                            draft.canViewVehicles ? _onViewVehicle : null,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              const Color(RidesColors.sheetNavyDeep),
                          disabledBackgroundColor:
                              const Color(RidesColors.sheetNavyDeep),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white54,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(RidesSheet.buttonRadius),
                          ),
                        ),
                        child: Text(
                          'View Vehicle',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.pill,
    required this.pillColor,
    required this.title,
    required this.hint,
    required this.onTap,
    this.onRemove,
  });

  final String pill;
  final Color pillColor;
  final String title;
  final String hint;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              pill,
              style: textTheme.bodyMedium?.copyWith(
                color: pillColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: textTheme.labelSmall?.copyWith(
                    color: const Color(RidesColors.mutedOnNavy),
                  ),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(
                Icons.close_rounded,
                color: Color(RidesColors.mutedOnNavy),
              ),
              tooltip: 'Remove stop',
            )
          else
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(RidesColors.mutedOnNavy),
            ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: const Color(0xFF334155)),
        ),
      ),
    );
  }
}
