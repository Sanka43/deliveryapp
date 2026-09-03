import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/services/maps/live_vehicle_markers.dart';
import 'package:mnd_delivery_app/core/utils/payhere_launcher.dart';
import 'package:mnd_delivery_app/core/utils/money_format.dart';
import 'package:mnd_delivery_app/core/utils/rider_delivery_eta.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/rider_live_location.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/rider_live_location_provider.dart';
import 'package:mnd_delivery_app/features/rides/data/ride_directions_service.dart';
import 'package:mnd_delivery_app/features/rides/data/rides_repository.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_trip.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/ride_route_provider.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/rides_providers.dart';
import 'package:mnd_delivery_app/features/rides/presentation/ride_status_style.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_map_markers.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_map_support.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_theme.dart';
import 'package:mnd_delivery_app/features/rides/presentation/widgets/ride_completed_card.dart';

class RidesLiveTrackingPage extends ConsumerStatefulWidget {
  const RidesLiveTrackingPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<RidesLiveTrackingPage> createState() =>
      _RidesLiveTrackingPageState();
}

class _RidesLiveTrackingPageState extends ConsumerState<RidesLiveTrackingPage> {
  GoogleMapController? _map;
  bool _followRider = true;
  bool _payingOnline = false;

  /// Each rider GPS update keys a *new* `liveRouteProvider` instance (see
  /// `LiveRouteKey`), so its `AsyncValue` starts back at loading with no
  /// data to show mid-refetch — briefly falling back to a straight line
  /// made the route visibly snap to a direct line on every position update.
  /// Holding the last successfully-fetched route here and only ever
  /// swapping it out for a newer *successful* fetch keeps the drawn line on
  /// an always-real road path. Cleared when the leg target itself changes
  /// (pickup → a stop → dropoff) so a stale route to the previous target
  /// never lingers pointing the wrong way.
  RideDrivingRoute? _lastGoodRoute;
  LatLng? _lastGoodRouteTarget;

  @override
  void initState() {
    super.initState();
    if (isRidesMapSupported()) {
      RidesMapMarkers.ensureLoaded().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  String _statusLabel(String status) => RideStatusStyle.labelFor(status);

  RideVehicleType? _iconLoadedFor;

  void _ensureVehicleIcon(RideVehicleType? type) {
    if (type == null || type == _iconLoadedFor) {
      return;
    }
    LiveVehicleMarkers.load(type).then((_) {
      if (mounted) {
        setState(() => _iconLoadedFor = type);
      }
    });
  }

  /// "Done" on an unpaid completed ride previously navigated away with no
  /// warning — nothing stopped the customer from leaving an online payment
  /// pending indefinitely. This forces an explicit choice instead.
  Future<void> _confirmLeaveUnpaid(BuildContext context, int fareLkr) async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Payment still pending'),
        content: Text(
          'You still owe LKR $fareLkr for this ride. '
          'You can pay now, or come back to it later from My Rides.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay and pay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave anyway'),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) {
      context.go(AppRoutes.customerRides);
    }
  }

  Future<void> _payOnline(String tripId) async {
    if (_payingOnline) {
      return;
    }
    setState(() => _payingOnline = true);
    try {
      final PayHereCheckout checkout = await ref
          .read(ridesRepositoryProvider)
          .createPayHereCheckoutForTrip(tripId: tripId);
      if (!mounted) {
        return;
      }
      final bool ok = await launchPayHereCheckout(
        context,
        checkoutPageUrl: checkout.checkoutPageUrl,
      );
      if (!ok && mounted) {
        showMndSnackBar(
          context,
          'Could not open PayHere checkout.',
          variant: MndSnackBarVariant.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showMndSnackBar(
          context,
          userFacingError(e, fallback: 'Could not start online payment.'),
          variant: MndSnackBarVariant.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _payingOnline = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AsyncValue<RideTrip?> tripAsync =
        ref.watch(rideTripProvider(widget.tripId));

    return Scaffold(
      body: tripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              userFacingError(
                e,
                fallback: 'Could not load trip tracking. Please try again.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (RideTrip? trip) {
          if (trip == null) {
            return const Center(child: Text('Trip not found'));
          }
          final String? riderId = trip.effectiveRiderId;
          final AsyncValue<RiderLiveLocation?> riderAsync = riderId == null
              ? const AsyncValue<RiderLiveLocation?>.data(null)
              : ref.watch(riderLiveLocationStreamProvider(riderId));
          final RiderLiveLocation? rider = riderAsync.asData?.value;
          final RideVehicleType? vehicle =
              trip.vehicle ?? RideVehicleType.fromFirestore(rider?.vehicleType);
          _ensureVehicleIcon(vehicle);

          final LatLng drop = LatLng(trip.dropoff.lat, trip.dropoff.lng);
          final LatLng pickup = LatLng(trip.pickup.lat, trip.pickup.lng);
          // The rider's actual next destination — pickup, then each stop in
          // order, then dropoff — not always dropoff regardless of status.
          final LatLng legTarget = LatLng(
            trip.currentLegTarget.lat,
            trip.currentLegTarget.lng,
          );
          final LatLng? riderPos =
              rider == null ? null : LatLng(rider.latitude, rider.longitude);

          if (_followRider && riderPos != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _map?.animateCamera(CameraUpdate.newLatLng(riderPos));
            });
          }

          final Set<Marker> markers = <Marker>{
            Marker(
              markerId: const MarkerId('pickup'),
              position: pickup,
              icon: RidesMapMarkers.pickup,
              anchor: const Offset(0.5, 1.0),
              infoWindow: const InfoWindow(title: 'Pick up'),
            ),
            Marker(
              markerId: const MarkerId('drop'),
              position: drop,
              icon: RidesMapMarkers.dropoff,
              anchor: const Offset(0.5, 1.0),
              infoWindow: const InfoWindow(title: 'Drop'),
            ),
            for (int i = 0; i < trip.stops.length; i++)
              Marker(
                markerId: MarkerId('stop_$i'),
                position: LatLng(trip.stops[i].lat, trip.stops[i].lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  i == trip.currentStopIndex && trip.status == 'in_progress'
                      ? BitmapDescriptor.hueOrange
                      : BitmapDescriptor.hueViolet,
                ),
                infoWindow: InfoWindow(title: 'Stop ${i + 1}'),
              ),
            if (riderPos != null)
              Marker(
                markerId: const MarkerId('driver'),
                position: riderPos,
                rotation: rider?.heading ?? 0,
                flat: rider?.heading != null,
                anchor: const Offset(0.5, 0.5),
                icon: LiveVehicleMarkers.iconFor(vehicle),
                infoWindow: const InfoWindow(title: 'Driver'),
              ),
          };

          if (_lastGoodRouteTarget != legTarget) {
            _lastGoodRoute = null;
            _lastGoodRouteTarget = legTarget;
          }
          if (riderPos != null) {
            final AsyncValue<RideDrivingRoute?> liveRoute = ref.watch(
              liveRouteProvider(
                LiveRouteKey(origin: riderPos, destination: legTarget),
              ),
            );
            final RideDrivingRoute? fetched = liveRoute.asData?.value;
            if (fetched != null) {
              _lastGoodRoute = fetched;
            }
          }
          final List<LatLng> roadPoints = roadRoutePoints(_lastGoodRoute);
          final Set<Polyline> lines = <Polyline>{
            if (roadPoints.length >= 2)
              Polyline(
                polylineId: const PolylineId('route'),
                width: 5,
                color: Colors.black,
                points: roadPoints,
              ),
          };

          final bool completed = trip.status == RideConstants.statusCompleted;
          final bool needsOnlinePay = trip.needsOnlinePayment;

          String? etaText;
          if (rider != null) {
            final Duration? dur = RiderDeliveryEta.travelDuration(
              riderLat: rider.latitude,
              riderLng: rider.longitude,
              dropLat: legTarget.latitude,
              dropLng: legTarget.longitude,
            );
            if (dur != null) {
              if (dur == Duration.zero) {
                etaText = 'Arriving soon';
              } else {
                etaText = '~${dur.inMinutes.clamp(1, 999)} min';
              }
            }
          }

          return Stack(
            children: <Widget>[
              if (isRidesMapSupported())
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: riderPos ?? pickup,
                    zoom: 13,
                  ),
                  onMapCreated: (GoogleMapController c) => _map = c,
                  markers: markers,
                  polylines: lines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onCameraMoveStarted: () {
                    if (_followRider) {
                      setState(() => _followRider = false);
                    }
                  },
                )
              else
                Container(
                  color: const Color(0xFFE8EEF6),
                  alignment: Alignment.center,
                  child: Text(_statusLabel(trip.status)),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.go(AppRoutes.customerRides),
                        ),
                      ),
                      const Spacer(),
                      if (!_followRider)
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _followRider = true),
                            child: const Text('Follow'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: completed
                      ? RideCompletedCard(
                          trip: trip,
                          payingOnline: _payingOnline,
                          onPayOnline: () => _payOnline(trip.id),
                          onDone: needsOnlinePay
                              ? () => _confirmLeaveUnpaid(
                                    context,
                                    trip.estimatedFareLkr,
                                  )
                              : () => context.go(AppRoutes.customerRides),
                        )
                      : Container(
                          width: double.infinity,
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(RidesColors.sheetNavy),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _statusLabel(trip.status),
                                style: textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (etaText != null)
                                Text(
                                  'ETA $etaText',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: const Color(RidesColors.mutedOnNavy),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                '${trip.vehicle?.label ?? trip.vehicleType} · '
                                '${MoneyFormat.lkr(trip.estimatedFareLkr, showDecimals: false)} · '
                                '${trip.distanceKm.toStringAsFixed(1)} km',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                trip.currentLegLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
