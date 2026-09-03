import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/features/rides/data/ride_directions_service.dart';
import 'package:mnd_delivery_app/features/rides/data/rides_repository.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_place.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_distance.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/ride_quotes_provider.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/ride_route_provider.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/rides_providers.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_map_markers.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_map_support.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_theme.dart';
import 'package:mnd_delivery_app/features/rides/presentation/widgets/rides_vehicle_card.dart';

/// Merged vehicle select + review / confirm (map + navy sheet).
class RidesConfirmPage extends ConsumerStatefulWidget {
  const RidesConfirmPage({super.key});

  @override
  ConsumerState<RidesConfirmPage> createState() => _RidesConfirmPageState();
}

/// Kept for older imports / route aliases.
typedef RidesVehiclePage = RidesConfirmPage;

class _RidesConfirmPageState extends ConsumerState<RidesConfirmPage> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  GoogleMapController? _mapController;
  final Map<String, RideFareQuote> _quotes = <String, RideFareQuote>{};
  bool _loadingQuotes = false;
  bool _submitting = false;
  bool _didFitBounds = false;
  bool _didFitRoadBounds = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final RideBookingDraft draft = ref.read(rideBookingDraftProvider);
    _noteController.text = draft.driverNote;
    _phoneController.text = draft.contactPhone;
    if (_phoneController.text.isEmpty) {
      final String? authPhone =
          ref.read(firebaseAuthProvider).currentUser?.phoneNumber;
      if (authPhone != null && authPhone.isNotEmpty) {
        _phoneController.text = authPhone;
      }
    }
    _seedLocalEstimates(draft);
    final RideFareQuotesKey? quotesKey = draftFareQuotesKey(draft);
    if (quotesKey != null) {
      final AsyncValue<List<RideFareQuote>> cached =
          ref.read(rideFareQuotesProvider(quotesKey));
      if (cached.hasValue && (cached.value?.isNotEmpty ?? false)) {
        // Local map only — never mutate providers during initState.
        _mergeQuotesLocal(cached.value!);
        _loadingQuotes = false;
      } else if (cached.isLoading || !cached.hasValue) {
        _loadingQuotes = !_quotesConfirmed;
      }
    }
    if (isRidesMapSupported()) {
      RidesMapMarkers.ensureLoaded().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
    // Provider writes must happen after the tree finishes building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncSelectedQuoteToDraft();
      _loadQuotes();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _phoneController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _seedLocalEstimates(
    RideBookingDraft draft, {
    Map<String, RideFareRates>? fareTable,
  }) {
    if (draft.pickup == null || draft.dropoff == null) {
      return;
    }
    final double km = RideDistance.multiLegKm(<({double lat, double lng})>[
      (lat: draft.pickup!.lat, lng: draft.pickup!.lng),
      for (final RidePlace stop in draft.stops) (lat: stop.lat, lng: stop.lng),
      (lat: draft.dropoff!.lat, lng: draft.dropoff!.lng),
    ]);
    for (final RideVehicleType type in RideVehicleType.values) {
      final RideFareQuote? existing = _quotes[type.firestoreValue];
      // Don't overwrite a confirmed server quote.
      if (existing != null && existing.quoteId.isNotEmpty) {
        continue;
      }
      _quotes[type.firestoreValue] = RideFareQuote(
        quoteId: '',
        vehicleType: type.firestoreValue,
        distanceKm: km,
        fareLkr: RideDistance.estimateFareLkr(
          type.firestoreValue,
          km,
          fareTable: fareTable,
          stopCount: draft.stops.length,
        ),
        expiresAtMs: 0,
      );
    }
  }

  bool get _quotesConfirmed =>
      _quotes.isNotEmpty &&
      _quotes.values.every((RideFareQuote q) => q.quoteId.isNotEmpty);

  void _mergeQuotesLocal(List<RideFareQuote> quotes) {
    for (final RideFareQuote q in quotes) {
      if (q.vehicleType.isNotEmpty && q.quoteId.isNotEmpty) {
        _quotes[q.vehicleType] = q;
      }
    }
  }

  void _syncSelectedQuoteToDraft() {
    final String selected = ref.read(rideBookingDraftProvider).vehicleType;
    final RideFareQuote? current = _quotes[selected];
    if (current == null || current.quoteId.isEmpty) {
      return;
    }
    final RideFareQuote? existing = ref.read(rideBookingDraftProvider).quote;
    if (existing?.quoteId == current.quoteId &&
        existing?.vehicleType == current.vehicleType) {
      return;
    }
    ref.read(rideBookingDraftProvider.notifier).setQuote(current);
  }

  void _applyServerQuotes(List<RideFareQuote> quotes) {
    _mergeQuotesLocal(quotes);
    _syncSelectedQuoteToDraft();
  }

  Future<void> _loadQuotes({bool forceRefresh = false}) async {
    final RideBookingDraft draft = ref.read(rideBookingDraftProvider);
    final RideFareQuotesKey? key = draftFareQuotesKey(draft);
    if (key == null) {
      if (mounted) {
        context.pop();
      }
      return;
    }

    if (!forceRefresh) {
      final AsyncValue<List<RideFareQuote>> cached =
          ref.read(rideFareQuotesProvider(key));
      if (cached.hasValue) {
        final List<RideFareQuote>? quotes = cached.value;
        if (quotes != null && quotes.isNotEmpty) {
          _applyServerQuotes(quotes);
          if (mounted) {
            setState(() {
              _loadingQuotes = false;
              _error = null;
            });
          }
          return;
        }
      }
    } else {
      ref.invalidate(rideFareQuotesProvider(key));
    }

    setState(() {
      _loadingQuotes = true;
      _error = null;
    });
    try {
      final List<RideFareQuote> quotes =
          await ref.read(rideFareQuotesProvider(key).future);
      if (!mounted) {
        return;
      }
      _applyServerQuotes(quotes);
      setState(() {
        _loadingQuotes = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingError(
            e,
            fallback: 'Could not load fare quotes. Please try again.',
          );
          _loadingQuotes = false;
        });
      }
    }
  }

  Future<void> _fitRoute(
    RidePlace pickup,
    RidePlace dropoff,
    RideDrivingRoute? road, {
    List<RidePlace> stops = const <RidePlace>[],
  }) async {
    if (_mapController == null) {
      return;
    }
    final bool hasRoad = road != null && road.points.length >= 2;
    if (hasRoad) {
      if (_didFitRoadBounds) {
        return;
      }
      _didFitRoadBounds = true;
      _didFitBounds = true;
    } else if (_didFitBounds) {
      return;
    } else {
      _didFitBounds = true;
    }
    final List<LatLng> points = fitBoundsPoints(
      pickup: pickup,
      dropoff: dropoff,
      route: road,
      stops: stops,
    );
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final LatLng p in points) {
      minLat = minLat < p.latitude ? minLat : p.latitude;
      maxLat = maxLat > p.latitude ? maxLat : p.latitude;
      minLng = minLng < p.longitude ? minLng : p.longitude;
      maxLng = maxLng > p.longitude ? maxLng : p.longitude;
    }
    final double padLat = ((maxLat - minLat).abs() * 0.2).clamp(0.002, 0.04);
    final double padLng = ((maxLng - minLng).abs() * 0.2).clamp(0.002, 0.04);
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - padLat, minLng - padLng),
          northeast: LatLng(maxLat + padLat, maxLng + padLng),
        ),
        56,
      ),
    );
  }

  void _selectVehicle(String type) {
    final RideFareQuote? q = _quotes[type];
    if (q != null && q.quoteId.isNotEmpty) {
      ref.read(rideBookingDraftProvider.notifier).setQuote(q);
    } else {
      ref.read(rideBookingDraftProvider.notifier).setVehicleType(type);
    }
  }

  Future<void> _confirm() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      navigateToSignIn(
        ref,
        context,
        redirectTo: AppRoutes.customerRidesVehicle,
      );
      return;
    }

    final RideBookingDraft draft = ref.read(rideBookingDraftProvider);
    final String phone = _phoneController.text.trim();
    final String note = _noteController.text.trim();
    ref.read(rideBookingDraftProvider.notifier).setDriverNote(note);
    ref.read(rideBookingDraftProvider.notifier).setContactPhone(phone);

    final RideFareQuote? quote = _quotes[draft.vehicleType] ?? draft.quote;
    if (quote == null || quote.quoteId.isEmpty) {
      showMndSnackBar(context, 'Confirming fares… try again in a moment.', variant: MndSnackBarVariant.warning);
      return;
    }
    if (phone.length < 8) {
      showMndSnackBar(context, 'Enter a contact phone for the driver.', variant: MndSnackBarVariant.warning);
      return;
    }

    ref.read(rideBookingDraftProvider.notifier).setQuote(quote);
    setState(() => _submitting = true);
    final RidesRepository repo = ref.read(ridesRepositoryProvider);

    try {
      // Cash and PayHere both start driver search immediately — PayHere
      // trips are paid online after the ride ends, not before matching.
      final String tripId = await repo.confirmCashRide(
        quoteId: quote.quoteId,
        contactPhone: phone,
        driverNote: note,
        paymentMethod: draft.paymentMethod,
      );
      if (!mounted) {
        return;
      }
      ref.read(rideBookingDraftProvider.notifier).reset();
      context.go(AppRoutes.customerRideTrip(tripId));
    } catch (e) {
      if (mounted) {
        showMndSnackBar(
          context,
          userFacingError(e, fallback: 'Could not book this ride.'),
          variant: MndSnackBarVariant.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  int _scaledEta(int baseMinutes, String vehicleType) {
    final double factor = switch (vehicleType) {
      'bike' => 0.9,
      'car' => 0.85,
      _ => 1.0,
    };
    return (baseMinutes * factor).round().clamp(1, 9999);
  }

  @override
  Widget build(BuildContext context) {
    final RideBookingDraft draft = ref.watch(rideBookingDraftProvider);
    if (draft.pickup == null || draft.dropoff == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(AppRoutes.customerRides);
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Keep fare-config + quote providers subscribed (prefetch / in-flight).
    ref.watch(rideFareConfigProvider);
    final RideFareQuotesKey? quotesKey = draftFareQuotesKey(draft);
    if (quotesKey != null) {
      // Watching keeps the cached/in-flight Future alive; _loadQuotes applies it.
      ref.watch(rideFareQuotesProvider(quotesKey));
    }
    ref.listen<AsyncValue<RideFareConfig>>(rideFareConfigProvider, (
      AsyncValue<RideFareConfig>? prev,
      AsyncValue<RideFareConfig> next,
    ) {
      final RideFareConfig? cfg = next.asData?.value;
      if (cfg == null || !mounted) {
        return;
      }
      setState(() {
        _seedLocalEstimates(
          ref.read(rideBookingDraftProvider),
          fareTable: cfg.rates,
        );
      });
    });
    final RidePlace? pickup = draft.pickup;
    final RidePlace? dropoff = draft.dropoff;
    final AsyncValue<RideDrivingRoute?> routeAsync =
        ref.watch(draftRideRouteProvider);
    final RideDrivingRoute? road = routeAsync.asData?.value;
    final double distanceKm = road?.distanceKm ??
        (pickup != null && dropoff != null
            ? RideDistance.multiLegKm(<({double lat, double lng})>[
                (lat: pickup.lat, lng: pickup.lng),
                for (final RidePlace stop in draft.stops)
                  (lat: stop.lat, lng: stop.lng),
                (lat: dropoff.lat, lng: dropoff.lng),
              ])
            : (_quotes[draft.vehicleType]?.distanceKm ??
                draft.quote?.distanceKm ??
                0));
    final String traffic = road != null
        ? '${road.durationMinutes} min · road'
        : (draft.quote?.trafficLabel ?? 'Normal traffic');
    final int selectedFare = _quotes[draft.vehicleType]?.fareLkr ??
        draft.quote?.fareLkr ??
        0;
    final bool canConfirm = _quotesConfirmed && !_submitting;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double sheetMaxHeight = MediaQuery.sizeOf(context).height * 0.72;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    if (pickup != null && dropoff != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Straight line immediately; re-fit once when Directions arrives.
        _fitRoute(pickup, dropoff, road, stops: draft.stops);
      });
    }

    final Set<Marker> markers = <Marker>{
      if (pickup != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickup.lat, pickup.lng),
          infoWindow: const InfoWindow(title: 'Pick up'),
          icon: RidesMapMarkers.pickup,
          anchor: const Offset(0.5, 1.0),
        ),
      if (dropoff != null)
        Marker(
          markerId: const MarkerId('drop'),
          position: LatLng(dropoff.lat, dropoff.lng),
          infoWindow: const InfoWindow(title: 'Drop'),
          icon: RidesMapMarkers.dropoff,
          anchor: const Offset(0.5, 1.0),
        ),
      for (int i = 0; i < draft.stops.length; i++)
        Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(draft.stops[i].lat, draft.stops[i].lng),
          infoWindow: InfoWindow(title: 'Stop ${i + 1}'),
          icon: RidesMapMarkers.stopAt(i),
          anchor: const Offset(0.5, 1.0),
        ),
    };
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

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          if (isRidesMapSupported() && pickup != null && dropoff != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (pickup.lat + dropoff.lat) / 2,
                  (pickup.lng + dropoff.lng) / 2,
                ),
                zoom: 12,
              ),
              onMapCreated: (GoogleMapController c) {
                _mapController = c;
                _fitRoute(pickup, dropoff, road, stops: draft.stops);
              },
              markers: markers,
              polylines: polylines,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            )
          else
            Container(color: const Color(0xFFE8EEF6)),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x990B1F4A),
                    Color(0x000B1F4A),
                  ],
                  stops: <double>[0, 0.35],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black26,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Select your ride',
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      shadows: const <Shadow>[
                        Shadow(blurRadius: 10, color: Colors.black45),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${distanceKm.toStringAsFixed(1)} km · $traffic',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RidesSheet.outerMargin,
                    0,
                    RidesSheet.outerMargin,
                    RidesSheet.outerMargin,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: sheetMaxHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Flexible(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(RidesColors.sheetNavy),
                              borderRadius:
                                  BorderRadius.circular(RidesSheet.cardRadius),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x40000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                RidesSheet.cardPaddingH,
                                RidesSheet.cardPaddingTop,
                                RidesSheet.cardPaddingH,
                                RidesSheet.cardPaddingBottom,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          'Choose a vehicle',
                                          style:
                                              textTheme.titleSmall?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (_loadingQuotes && !_quotesConfirmed)
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white70,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_error != null && !_quotesConfirmed)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8,
                                      ),
                                      child: Column(
                                        children: <Widget>[
                                          Text(
                                            _error!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Colors.white70,
                                                ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                _loadQuotes(forceRefresh: true),
                                            child: const Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  SizedBox(
                                    height: RidesVehicleCard.listHeight,
                                    child: Row(
                                      children: <Widget>[
                                        for (final RideVehicleType type
                                            in RideVehicleType.values)
                                          ...<Widget>[
                                            if (type !=
                                                RideVehicleType.values.first)
                                              const SizedBox(width: 8),
                                            Expanded(
                                              child: RidesVehicleCard(
                                                type: type,
                                                etaMinutes: road?.durationMinutes !=
                                                        null
                                                    ? _scaledEta(
                                                        road!.durationMinutes,
                                                        type.firestoreValue,
                                                      )
                                                    : RideDistance.etaMinutes(
                                                        type.firestoreValue,
                                                        _quotes[type
                                                                    .firestoreValue]
                                                                ?.distanceKm ??
                                                            distanceKm,
                                                      ),
                                                fareLkr: _quotes[type
                                                            .firestoreValue]
                                                        ?.fareLkr ??
                                                    0,
                                                fareConfirmed: (_quotes[type
                                                                .firestoreValue]
                                                            ?.quoteId ??
                                                        '')
                                                    .isNotEmpty,
                                                selected:
                                                    draft.vehicleType ==
                                                        type.firestoreValue,
                                                isNew: type ==
                                                    RideVehicleType.bike,
                                                onTap: () => _selectVehicle(
                                                  type.firestoreValue,
                                                ),
                                              ),
                                            ),
                                          ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _noteController,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF102040),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      hintText: 'Add note to driver',
                                      hintStyle:
                                          textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.edit_note_rounded,
                                        color: Color(0xFF607090),
                                        size: 22,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Payment',
                                    style: textTheme.titleSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: _PaymentButton(
                                          label: 'Cash',
                                          icon: Icons.payments_outlined,
                                          selected: draft.paymentMethod ==
                                              RideConstants.paymentCash,
                                          enabled: !_submitting,
                                          onTap: () => ref
                                              .read(
                                                rideBookingDraftProvider
                                                    .notifier,
                                              )
                                              .setPaymentMethod(
                                                RideConstants.paymentCash,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _PaymentButton(
                                          label: 'Pay online',
                                          icon: Icons.credit_card_rounded,
                                          selected: draft.paymentMethod ==
                                              RideConstants.paymentPayHere,
                                          enabled: !_submitting,
                                          onTap: () => ref
                                              .read(
                                                rideBookingDraftProvider
                                                    .notifier,
                                              )
                                              .setPaymentMethod(
                                                RideConstants.paymentPayHere,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    draft.paymentMethod ==
                                            RideConstants.paymentPayHere
                                        ? 'Pay securely online via PayHere'
                                        : 'Pay the driver in cash',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: const Color(
                                        RidesColors.mutedOnNavy,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(
                                    color: Color(0x33FFFFFF),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        _quotesConfirmed
                                            ? 'Estimated fare'
                                            : 'Estimate (confirming…)',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: const Color(0xFF9BB0D4),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _loadingQuotes && !_quotesConfirmed
                                            ? '…'
                                            : 'LKR $selectedFare',
                                        style: textTheme.titleSmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: RidesSheet.cardGap),
                        SizedBox(
                          width: double.infinity,
                          height: RidesSheet.primaryButtonHeight,
                          child: FilledButton(
                            onPressed: canConfirm ? _confirm : null,
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  RidesColors.accentBlue,
                              disabledBackgroundColor:
                                  RidesColors.accentBlue
                                      .withValues(alpha: 0.4),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  RidesSheet.buttonRadius,
                                ),
                              ),
                              elevation: 0,
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    !_quotesConfirmed
                                        ? 'Confirming fares…'
                                        : 'Confirm order',
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentButton extends StatelessWidget {
  const _PaymentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    const Color accent = RidesColors.accentBlue;

    return Opacity(
      opacity: enabled ? 1 : 0.72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(RidesSheet.buttonRadius),
          child: Ink(
            height: 46,
            decoration: BoxDecoration(
              color: selected && enabled
                  ? accent
                  : Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(RidesSheet.buttonRadius),
              border: Border.all(
                color: selected && enabled
                    ? accent
                    : Colors.white.withValues(alpha: 0.22),
                width: 1.5,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        icon,
                        size: RidesSheet.actionIconSize,
                        color: selected && enabled
                            ? Colors.white
                            : Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: textTheme.bodyMedium?.copyWith(
                          color: selected && enabled
                              ? Colors.white
                              : Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
