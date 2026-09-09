import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/services/maps/rider_maps_helper.dart';
import 'package:mnd_rider/core/services/rider_location_service.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/utils/rider_delivery_eta.dart';
import 'package:mnd_rider/core/widgets/rider_branded_dialog.dart';
import 'package:mnd_rider/core/widgets/rider_drive_sheet.dart';
import 'package:mnd_rider/core/widgets/rider_map_chrome.dart';
import 'package:mnd_rider/core/widgets/rider_primary_cta.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/core/widgets/rider_status_pill.dart';
import 'package:mnd_rider/features/trip/domain/rider_trip_phase.dart';
import 'package:mnd_rider/features/trip/presentation/providers/rider_trip_tracking_provider.dart';
import 'package:mnd_rider/features/trip/presentation/widgets/rider_live_trip_map.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';
import 'package:mnd_rider/features/trips/presentation/widgets/rider_ride_summary_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

/// Live passenger-ride navigation: pickup → dropoff with status CTAs.
class RiderRideNavigationPage extends ConsumerStatefulWidget {
  const RiderRideNavigationPage({super.key, required this.trip});

  final RiderPassengerTrip trip;

  @override
  ConsumerState<RiderRideNavigationPage> createState() =>
      _RiderRideNavigationPageState();
}

class _RiderRideNavigationPageState
    extends ConsumerState<RiderRideNavigationPage> {
  bool _busy = false;
  bool _showSummary = false;
  late final RiderLocationService _locationService;
  final GlobalKey _sheetKey = GlobalKey();
  double _sheetHeight = 260;

  /// True when this page was opened directly on a ride that had already
  /// finished (tapped from "Passenger rides" / trip history) rather than
  /// one completing live during this session — those two cases need very
  /// different UI: a plain read-only recap here vs. the driving screen.
  late final bool _openedAlreadyCompleted =
      widget.trip.status.trim().toLowerCase() == 'completed';

  void _measureSheetAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final double? h = _sheetKey.currentContext?.size?.height;
      if (h != null && mounted && (h - _sheetHeight).abs() > 1) {
        setState(() => _sheetHeight = h);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _locationService = ref.read(riderLocationServiceProvider);
    if (!_openedAlreadyCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_locationService.setTrackingEnabled(true));
        unawaited(_locationService.setTripMode(true));
      });
    }
  }

  @override
  void dispose() {
    unawaited(_locationService.setTripMode(false));
    super.dispose();
  }

  RiderPassengerTrip get _trip =>
      ref.watch(riderPassengerTripProvider(widget.trip.id)).valueOrNull ??
      widget.trip;

  /// When `in_progress`, the active leg is driven by [RiderPassengerTrip
  /// .currentStopIndex] — heading to the next un-visited stop, or straight
  /// to drop-off once all stops are done.
  RiderTripPhase get _basePhase {
    switch (_trip.status.trim().toLowerCase()) {
      case 'arrived':
        return RiderTripPhase.atVendor;
      case 'in_progress':
        if (_trip.currentStopIndex == 0 && _trip.stops.isNotEmpty) {
          return RiderTripPhase.navigateToStop1;
        }
        if (_trip.currentStopIndex == 1 && _trip.stops.length > 1) {
          return RiderTripPhase.navigateToStop2;
        }
        return RiderTripPhase.navigateToCustomer;
      case 'completed':
        return RiderTripPhase.atCustomer;
      case 'accepted':
      default:
        return RiderTripPhase.navigateToVendor;
    }
  }

  /// When en route and within ~35 m of the current leg's target, show the
  /// "arrived" chrome for that leg (stop or final drop-off).
  RiderTripPhase _phaseFor(LatLng? rider) {
    final RiderTripPhase base = _basePhase;
    final bool isNavigating =
        base == RiderTripPhase.navigateToCustomer ||
        base == RiderTripPhase.navigateToStop1 ||
        base == RiderTripPhase.navigateToStop2;
    if (!isNavigating || rider == null) {
      return base;
    }
    final LatLng? target = _legTarget(base);
    if (target == null) {
      return base;
    }
    final double km = RiderDeliveryEta.haversineKm(
      rider.latitude,
      rider.longitude,
      target.latitude,
      target.longitude,
    );
    if (km > RiderDeliveryEta.arrivedThresholdKm) {
      return base;
    }
    return switch (base) {
      RiderTripPhase.navigateToStop1 => RiderTripPhase.atStop1,
      RiderTripPhase.navigateToStop2 => RiderTripPhase.atStop2,
      _ => RiderTripPhase.atCustomer,
    };
  }

  LatLng? get _pickup => RiderMapsHelper.latLngFromOrder(
    lat: _trip.pickupLat,
    lng: _trip.pickupLng,
  );

  LatLng? get _dropoff => RiderMapsHelper.latLngFromOrder(
    lat: _trip.dropoffLat,
    lng: _trip.dropoffLng,
  );

  LatLng? _stopTarget(int index) {
    if (index < 0 || index >= _trip.stops.length) {
      return null;
    }
    return RiderMapsHelper.latLngFromOrder(
      lat: _trip.stops[index].lat,
      lng: _trip.stops[index].lng,
    );
  }

  String _stopLabel(int index) {
    if (index < 0 || index >= _trip.stops.length) {
      return 'Stop';
    }
    return _trip.stops[index].label;
  }

  /// Map/nav target for any leg (pickup, a stop, or drop-off).
  LatLng? _legTarget(RiderTripPhase phase) {
    final int? stopIndex = phase.stopIndex;
    if (stopIndex != null) {
      return _stopTarget(stopIndex);
    }
    return phase.isVendorLeg ? _pickup : _dropoff;
  }

  String _legAddress(RiderTripPhase phase) {
    final int? stopIndex = phase.stopIndex;
    if (stopIndex != null) {
      return _stopLabel(stopIndex);
    }
    return phase.isVendorLeg ? _trip.pickupLabel : _trip.dropoffLabel;
  }

  (String, RiderStatusPillTone) _phaseChrome(RiderTripPhase phase) {
    switch (phase) {
      case RiderTripPhase.navigateToVendor:
        return ('To pickup', RiderStatusPillTone.arriving);
      case RiderTripPhase.atVendor:
        return ('At pickup', RiderStatusPillTone.warning);
      case RiderTripPhase.navigateToStop1:
        return ('To stop 1', RiderStatusPillTone.arriving);
      case RiderTripPhase.atStop1:
        return ('At stop 1', RiderStatusPillTone.warning);
      case RiderTripPhase.navigateToStop2:
        return ('To stop 2', RiderStatusPillTone.arriving);
      case RiderTripPhase.atStop2:
        return ('At stop 2', RiderStatusPillTone.warning);
      case RiderTripPhase.navigateToCustomer:
        return ('On trip', RiderStatusPillTone.delivering);
      case RiderTripPhase.atCustomer:
        return ('At dropoff', RiderStatusPillTone.delivering);
    }
  }

  Future<void> _openMaps(String address) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeQueryComponent(address)}&travelmode=driving',
    );
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || ok) {
      return;
    }
    showRiderSnackBar(context, 'Could not open Google Maps');
  }

  Future<void> _callPassenger() async {
    final String digits = _trip.contactPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) {
      return;
    }
    final Uri uri = Uri(scheme: 'tel', path: digits);
    if (!await launchUrl(uri) && mounted) {
      showRiderSnackBar(context, 'Could not open phone dialer');
    }
  }

  Future<void> _advance(String next) async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    final String? err = await ref
        .read(riderTripsRepositoryProvider)
        .updateTripStatus(_trip.id, next);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (err != null) {
      showRiderSnackBar(context, err);
      return;
    }
    if (next == 'cancelled') {
      context.pop(true);
    }
  }

  /// Completing a ride needs the rider's current position — within 100m of
  /// the pinned drop-off that's all the backend requires; farther than that
  /// it also needs the passenger's PIN, so this loops: try, and if the
  /// backend says a PIN is needed (missing or wrong), prompt for one and
  /// retry with it.
  Future<void> _completeRide({String? dropoffCode}) async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    final LatLng? pos = ref.read(riderTripMapPositionProvider);
    if (pos == null) {
      setState(() => _busy = false);
      showRiderSnackBar(
        context,
        'Could not get your current location. Try again.',
      );
      return;
    }
    final RideCompletionOutcome outcome = await ref
        .read(riderTripsRepositoryProvider)
        .completeTrip(
          tripId: _trip.id,
          riderLat: pos.latitude,
          riderLng: pos.longitude,
          dropoffCode: dropoffCode,
        );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (outcome.isSuccess) {
      // Show the cost recap + payment-confirmation sheet instead of
      // popping immediately — see RiderRideSummarySheet.
      setState(() => _showSummary = true);
      return;
    }
    if (outcome.requiresCode) {
      final String? code = await _promptDropoffCode(errorText: outcome.error);
      if (code != null && code.isNotEmpty && mounted) {
        await _completeRide(dropoffCode: code);
      }
      return;
    }
    showRiderSnackBar(context, outcome.error ?? 'Could not complete trip.');
  }

  /// Asks the rider for the passenger's drop-off PIN — shown once they're
  /// too far from the pinned drop-off to complete without it.
  Future<String?> _promptDropoffCode({String? errorText}) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => _DropoffCodeDialog(errorText: errorText),
    );
  }

  Future<String?> _confirmCashPayment() {
    return ref.read(riderTripsRepositoryProvider).confirmCashPayment(_trip.id);
  }

  /// Arrived at an intermediate stop — advances the leg without touching
  /// trip `status` (only the final leg completes the trip).
  Future<void> _advanceStop() async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    final String? err = await ref
        .read(riderTripsRepositoryProvider)
        .advanceStop(_trip.id);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (err != null) {
      showRiderSnackBar(context, err);
    }
  }

  Future<void> _cancel() async {
    final bool ok = await showRiderConfirmDialog(
      context,
      title: 'Cancel this ride?',
      message: 'The passenger will be notified and the trip will end.',
      confirmLabel: 'Cancel ride',
      cancelLabel: 'Keep',
      isDestructive: true,
    );
    if (ok) {
      await _advance('cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    // The passenger can cancel while accepted/arrived/in_progress — without
    // this, the screen kept rendering pickup/trip CTAs as if nothing
    // happened, and the rider only found out by tapping a button and
    // hitting a raw rules rejection.
    if (_trip.status.trim().toLowerCase() == 'cancelled') {
      return Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.cancel_rounded, color: cs.error, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'This ride was cancelled',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The passenger cancelled this ride. Nothing more to do here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      RiderPrimaryCta(
                        label: 'Back to rides',
                        expanded: false,
                        color: AppColors.primaryBlue,
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Semantics(
                  button: true,
                  label: 'Back',
                  child: RiderMapChrome(
                    padding: EdgeInsets.zero,
                    borderRadius: 99,
                    onTap: () => context.pop(),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: cs.onSurface,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Opened straight onto a ride that already finished — just the recap
    // (route, fare, payment) with no map or driving controls, matching how
    // a completed delivery opens to a plain details view instead of the
    // live tracking screen.
    if (_openedAlreadyCompleted) {
      return Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        appBar: AppBar(title: const Text('Ride details')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: RiderRideSummarySheet(trip: _trip),
          ),
        ),
      );
    }

    final LatLng? riderPos = ref.watch(riderTripMapPositionProvider);
    final RiderTripPhase phase = _phaseFor(riderPos);
    final bool pickupLeg = phase.isVendorLeg;
    // CTAs follow Firestore status/stop progress, not proximity chrome.
    final RiderTripPhase ctaPhase = _basePhase;
    final String mapsAddress = _legAddress(phase);
    final (String phaseLabel, RiderStatusPillTone phaseTone) = _phaseChrome(
      phase,
    );
    final LatLng? target = _legTarget(phase);
    final RiderTripEtaSnapshot eta = ref.watch(
      riderTripEtaProvider(
        RiderTripEtaInput(
          target: target,
          label: pickupLeg ? 'To pickup' : 'To dropoff',
        ),
      ),
    );

    late final String ctaLabel;
    late final Color ctaColor;
    late final IconData ctaIcon;
    late final Future<void> Function() ctaAction;
    switch (ctaPhase) {
      case RiderTripPhase.navigateToVendor:
        ctaLabel = 'Arrived';
        ctaColor = AppColors.pickupGreen;
        ctaIcon = Icons.place_rounded;
        ctaAction = () => _advance('arrived');
      case RiderTripPhase.atVendor:
        ctaLabel = 'Start trip';
        ctaColor = AppColors.accentBlue;
        ctaIcon = Icons.play_arrow_rounded;
        ctaAction = () => _advance('in_progress');
      case RiderTripPhase.navigateToStop1:
      case RiderTripPhase.atStop1:
        ctaLabel = 'Arrived at stop 1';
        ctaColor = AppColors.pickupGreen;
        ctaIcon = Icons.flag_rounded;
        ctaAction = _advanceStop;
      case RiderTripPhase.navigateToStop2:
      case RiderTripPhase.atStop2:
        ctaLabel = 'Arrived at stop 2';
        ctaColor = AppColors.pickupGreen;
        ctaIcon = Icons.flag_rounded;
        ctaAction = _advanceStop;
      case RiderTripPhase.navigateToCustomer:
      case RiderTripPhase.atCustomer:
        ctaLabel = 'Complete';
        ctaColor = AppColors.onlineGreen;
        ctaIcon = Icons.check_circle_rounded;
        ctaAction = () => _completeRide();
    }

    _measureSheetAfterFrame();
    final double topChromePadding = MediaQuery.paddingOf(context).top + 68;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RiderLiveTripMap(
            phase: phase,
            vendorPosition: _pickup,
            customerPosition: _dropoff,
            vendorTitle: 'Pickup',
            customerTitle: 'Dropoff',
            isRide: true,
            stopPositions: <LatLng>[
              for (int i = 0; i < _trip.stops.length; i++)
                if (_stopTarget(i) != null) _stopTarget(i)!,
            ],
            stopTitles: <String>[
              for (int i = 0; i < _trip.stops.length; i++)
                if (_stopTarget(i) != null) 'Stop ${i + 1}',
            ],
            topPadding: topChromePadding,
            bottomPadding: _sheetHeight + 16,
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: <Widget>[
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: RiderMapChrome(
                      padding: EdgeInsets.zero,
                      borderRadius: 99,
                      onTap: () => context.pop(),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: cs.onSurface,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  RiderStatusPill(
                    label: phaseLabel,
                    tone: phaseTone,
                    compact: true,
                  ),
                  const Spacer(),
                  if (_trip.contactPhone.isNotEmpty)
                    Semantics(
                      button: true,
                      label: 'Call passenger',
                      child: RiderMapChrome(
                        padding: EdgeInsets.zero,
                        borderRadius: 99,
                        onTap: _busy ? null : _callPassenger,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.phone_rounded,
                            color: cs.onSurface,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: KeyedSubtree(
              key: _sheetKey,
              child: RiderDriveSheet(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: _showSummary
                    ? RiderRideSummarySheet(
                        trip: _trip,
                        onConfirmCashPayment: _confirmCashPayment,
                        onDone: () => context.pop(true),
                      )
                    : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                eta.durationText,
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                      letterSpacing: 0,
                                      height: 1,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${eta.label} · ${eta.distanceText}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: cs.surfaceContainerLow,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Open Maps',
                            onPressed: _busy
                                ? null
                                : () => _openMaps(mapsAddress),
                            icon: Icon(
                              Icons.navigation_rounded,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      mapsAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_trip.vehicleType.toUpperCase()} · '
                      '${LkrFormat.money(_trip.estimatedFareLkr)}'
                      '${(_trip.driverNote ?? '').isNotEmpty ? ' · ${_trip.driverNote}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _trip.isOnlinePayment
                          ? (_trip.isPaid
                                ? 'Paid online — no cash to collect'
                                : 'Online payment — collected after the ride, no cash now')
                          : 'Collect ${LkrFormat.money(_trip.estimatedFareLkr)} cash from passenger',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _trip.isOnlinePayment
                            ? AppColors.onlineGreen
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    RiderPrimaryCta(
                      label: ctaLabel,
                      icon: ctaIcon,
                      color: ctaColor,
                      busy: _busy,
                      height: AppSpacing.ctaHeightLg,
                      onPressed: _busy ? null : ctaAction,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : _cancel,
                      child: Text(
                        'Cancel ride',
                        style: TextStyle(color: cs.onSurfaceVariant),
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

/// Prompts the rider for the passenger's 4-digit drop-off PIN — shown when
/// completing a ride more than 100m from the pinned drop-off. [errorText],
/// when set, means this is a retry after a missing/incorrect PIN.
class _DropoffCodeDialog extends StatefulWidget {
  const _DropoffCodeDialog({this.errorText});

  final String? errorText;

  @override
  State<_DropoffCodeDialog> createState() => _DropoffCodeDialogState();
}

class _DropoffCodeDialogState extends State<_DropoffCodeDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String code = _controller.text.trim();
    if (code.length == 4) {
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Dialog(
      backgroundColor: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Enter drop-off PIN',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "You're away from the pinned drop-off. Ask the passenger "
              'for the PIN shown on their ride screen to complete this ride.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                errorText: widget.errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (BuildContext context, TextEditingValue value, _) {
                      return FilledButton(
                        onPressed: value.text.trim().length == 4
                            ? _submit
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.buttonRadius,
                            ),
                          ),
                        ),
                        child: const Text('Complete ride'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
