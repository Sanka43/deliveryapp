import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/services/maps/rider_maps_helper.dart';
import 'package:mnd_rider/core/services/rider_location_service.dart';
import 'package:mnd_rider/core/services/rider_path_distance_tracker.dart';
import 'package:mnd_rider/core/utils/delivery_pricing.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/utils/rider_delivery_eta.dart';
import 'package:mnd_rider/core/widgets/rider_map_chrome.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/core/widgets/rider_status_pill.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/orders/presentation/providers/vendor_phone_provider.dart';
import 'package:mnd_rider/features/trip/domain/rider_trip_phase.dart';
import 'package:mnd_rider/features/trip/presentation/providers/rider_trip_tracking_provider.dart';
import 'package:mnd_rider/features/trip/presentation/widgets/rider_delivery_confirm_dialog.dart';
import 'package:mnd_rider/features/trip/presentation/widgets/rider_live_trip_map.dart';
import 'package:mnd_rider/features/trip/presentation/widgets/rider_trip_bottom_panel.dart';
import 'package:url_launcher/url_launcher.dart';

/// Live delivery tracking: map navigation, polylines, ETA, Firestore sync.
class RiderTripNavigationPage extends ConsumerStatefulWidget {
  const RiderTripNavigationPage({super.key, required this.order});

  final RiderOrderDetail order;

  @override
  ConsumerState<RiderTripNavigationPage> createState() =>
      _RiderTripNavigationPageState();
}

class _RiderTripNavigationPageState
    extends ConsumerState<RiderTripNavigationPage> {
  late RiderTripPhase _phase;
  bool _busy = false;
  late final RiderLocationService _locationService;
  late final RiderPathDistanceTracker _pathTracker;
  final GlobalKey _sheetKey = GlobalKey();
  // Falls back to RiderLiveTripMap's own default until the sheet is first
  // measured — without a real map padding, Google Maps fits/centers markers
  // using the *whole* widget area, including the space this sheet covers,
  // and they end up hidden behind it.
  double _sheetHeight = 320;

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
    _pathTracker = RiderPathDistanceTracker();
    _phase = riderTripPhaseFromOrder(widget.order);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _locationService.setTrackingEnabled(true);
      await _locationService.setTripMode(true);
      if (_phase.isCustomerLeg && widget.order.usesActualTripFee) {
        await _pathTracker.start();
        if (mounted) {
          setState(() {});
        }
      }
      if (mounted) {
        _syncAtCustomerProximity(ref.read(riderTripMapPositionProvider));
      }
    });
  }

  @override
  void dispose() {
    _pathTracker.dispose();
    unawaited(_locationService.setTripMode(false));
    super.dispose();
  }

  RiderOrderDetail get _order =>
      ref.watch(riderOrderDetailProvider(widget.order.id)).valueOrNull ??
      widget.order;

  LatLng? get _vendorPosition => RiderMapsHelper.latLngFromOrder(
    lat: _order.pickupLatitude,
    lng: _order.pickupLongitude,
  );

  LatLng? get _customerPosition => RiderMapsHelper.latLngFromOrder(
    lat: _order.dropoffLatitude,
    lng: _order.dropoffLongitude,
  );

  String get _pickupAddress {
    final String? p = _order.pickupAddress?.trim();
    if (p != null && p.isNotEmpty) {
      return p;
    }
    return _order.storeName;
  }

  (String, RiderStatusPillTone) get _phaseChrome {
    switch (_phase) {
      case RiderTripPhase.navigateToVendor:
        return ('To store', RiderStatusPillTone.arriving);
      case RiderTripPhase.atVendor:
        return ('At store', RiderStatusPillTone.warning);
      // Stop legs only apply to passenger rides, never delivery orders.
      case RiderTripPhase.navigateToStop1:
      case RiderTripPhase.atStop1:
      case RiderTripPhase.navigateToStop2:
      case RiderTripPhase.atStop2:
      case RiderTripPhase.navigateToCustomer:
        return ('Delivering', RiderStatusPillTone.delivering);
      case RiderTripPhase.atCustomer:
        return ('At customer', RiderStatusPillTone.delivering);
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

  Future<void> _callShop() async {
    final String? phone = ref
        .read(vendorPhoneProvider(_order.vendorId))
        .valueOrNull;
    final String digits = (phone ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) {
      if (mounted) {
        showRiderSnackBar(context, 'Shop phone not available');
      }
      return;
    }
    final Uri uri = Uri(scheme: 'tel', path: digits);
    if (!await launchUrl(uri) && mounted) {
      showRiderSnackBar(context, 'Could not open phone dialer');
    }
  }

  Future<bool> _updateStatus(String status) async {
    setState(() => _busy = true);
    final String? err = await ref
        .read(riderOrdersRepositoryProvider)
        .updateOrderStatus(orderId: _order.id, nextStatus: status);
    if (!mounted) {
      return false;
    }
    setState(() => _busy = false);
    if (err != null) {
      showRiderSnackBar(context, err);
      return false;
    }
    return true;
  }

  /// One tap covers pickup + heading out: writes `picked_up` (so the
  /// customer tracker still shows that milestone) then immediately
  /// `on_the_way`, instead of making the rider confirm each separately.
  Future<void> _onOrderPickedUp() async {
    HapticFeedback.mediumImpact();
    final bool pickedUpOk = await _updateStatus('picked_up');
    if (!pickedUpOk || !mounted) {
      return;
    }
    // If this leg fails, the order stays at `picked_up` server-side and the
    // rider stays on this button — tapping again no-ops the picked_up write
    // (already-current status) and retries on_the_way.
    final bool onTheWayOk = await _updateStatus('on_the_way');
    if (!onTheWayOk || !mounted) {
      return;
    }
    if (_order.usesActualTripFee) {
      await _pathTracker.start();
    }
    setState(() => _phase = RiderTripPhase.navigateToCustomer);
  }

  /// Local UX: flip to [RiderTripPhase.atCustomer] when within ~35 m of dropoff.
  void _syncAtCustomerProximity(LatLng? rider) {
    if (!_phase.isCustomerLeg || rider == null) {
      return;
    }
    final LatLng? dropoff = _customerPosition;
    if (dropoff == null) {
      return;
    }
    final double km = RiderDeliveryEta.haversineKm(
      rider.latitude,
      rider.longitude,
      dropoff.latitude,
      dropoff.longitude,
    );
    final bool near = km <= RiderDeliveryEta.arrivedThresholdKm;
    if (near && _phase != RiderTripPhase.atCustomer) {
      setState(() => _phase = RiderTripPhase.atCustomer);
    } else if (!near &&
        _phase == RiderTripPhase.atCustomer &&
        _order.status == 'on_the_way') {
      setState(() => _phase = RiderTripPhase.navigateToCustomer);
    }
  }

  Future<void> _onDelivered() async {
    HapticFeedback.heavyImpact();
    if (_order.usesActualTripFee) {
      await _completeActualTripDelivery();
      return;
    }
    final int collect = _order.collectAmountLkr();
    final bool confirmed = await showRiderDeliveryConfirmDialog(
      context,
      collectAmountLkr: collect,
      isPrepaidOnline: _order.isPrepaidOnline,
      awayFromDropoff: _phase != RiderTripPhase.atCustomer,
      breakdown: _collectBreakdown(collect),
    );
    if (!confirmed || !mounted) {
      return;
    }
    final bool ok = await _updateStatus('delivered');
    if (ok && mounted) {
      context.pop(true);
    }
  }

  /// Products / delivery / service-charge split for the collect card. Only
  /// returned when the parts reconcile with what the rider actually collects —
  /// `amountDueFromCustomerLkr` is written server-side and can differ from the
  /// sum, and a breakdown that doesn't add up is worse than none.
  List<RiderCollectLine> _collectBreakdown(int collect) {
    final List<RiderCollectLine> lines = <RiderCollectLine>[];
    if (!_order.productsPaid) {
      lines.add(
        RiderCollectLine(
          label: 'Products',
          amountLkr: _order.subtotalLkr - _order.discountLkr,
        ),
      );
    }
    if (_order.deliveryFeeLkr > 0) {
      lines.add(
        RiderCollectLine(label: 'Delivery', amountLkr: _order.deliveryFeeLkr),
      );
    }
    if (_order.serviceChargeLkr > 0) {
      lines.add(
        RiderCollectLine(
          label: 'Service charge',
          amountLkr: _order.serviceChargeLkr,
        ),
      );
    }
    final int sum = lines.fold<int>(
      0,
      (int s, RiderCollectLine l) => s + l.amountLkr,
    );
    if (lines.length < 2 || sum != collect) {
      return const <RiderCollectLine>[];
    }
    return lines;
  }

  Future<void> _completeActualTripDelivery() async {
    final double km = DeliveryPricing.roundTraveledKm(_pathTracker.traveledKm);
    final int fee = DeliveryPricing.feeLkrForActualTripKm(km);
    final int collect = _order.collectAmountLkr(estimatedDeliveryFeeLkr: fee);
    final bool isGuest = _order.isGuestCustomer;

    // Guest order (no MND account): the customer got a 4-digit code by SMS
    // when the order was placed. Collecting it here proves a real recipient
    // is at the address — the server rejects delivery completion without it.
    final TextEditingController codeController = TextEditingController();
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: isGuest,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.sheetRadius),
        ),
      ),
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            final bool codeValid = RegExp(
              r'^\d{4}$',
            ).hasMatch(codeController.text.trim());
            final bool canConfirm = !isGuest || codeValid;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Collect from customer',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Trip ${km.toStringAsFixed(1)} km · Delivery ${LkrFormat.money(fee)}',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (!_order.productsPaid) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'Products ${LkrFormat.money(_order.subtotalLkr - _order.discountLkr)} + delivery'
                          '${_order.serviceChargeLkr > 0 ? ' + service charge' : ''}',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ] else ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'Products already paid — delivery'
                          '${_order.serviceChargeLkr > 0 ? ' + service charge' : ' only'}',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (_order.serviceChargeLkr > 0) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          'Includes service charge ${LkrFormat.money(_order.serviceChargeLkr)}',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        LkrFormat.money(collect),
                        textAlign: TextAlign.center,
                        style: Theme.of(ctx).textTheme.displaySmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isGuest) ...<Widget>[
                        const SizedBox(height: 20),
                        Text(
                          'Ask the customer for their 4-digit code from SMS',
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: codeController,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 4,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: Theme.of(ctx).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 8,
                              ),
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: '0000',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: canConfirm
                            ? () => Navigator.of(ctx).pop(true)
                            : null,
                        child: const Text('Confirm delivered'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) {
      codeController.dispose();
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(riderOrdersRepositoryProvider)
          .completeDeliveryOrder(
            orderId: _order.id,
            traveledKm: km,
            confirmationCode: isGuest ? codeController.text.trim() : null,
          );
      if (mounted) {
        context.pop(true);
      }
    } on CompleteDeliveryException catch (e) {
      // A network drop can mean the first attempt actually succeeded
      // server-side even though this client never saw the response — check
      // the order's live status before showing a scary retry prompt, so the
      // rider isn't invited to tap again and risk submitting a different
      // traveledKm for a delivery that's already been recorded.
      bool alreadyDelivered = false;
      try {
        final RiderOrderDetail? latest = await ref
            .read(riderOrdersRepositoryProvider)
            .fetchOrderDetail(_order.id);
        alreadyDelivered = latest?.status == 'delivered';
      } catch (_) {
        // Best-effort re-check only — fall through to the original error.
      }
      if (mounted) {
        if (alreadyDelivered) {
          context.pop(true);
        } else {
          showRiderSnackBar(context, e.message);
        }
      }
    } finally {
      // Stop tracking regardless of outcome — a retry after a failed
      // attempt should submit the same traveledKm as the first attempt,
      // not a larger one accumulated while the rider waited to retry.
      await _pathTracker.stop();
      codeController.dispose();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String mapsAddress = _phase.isVendorLeg
        ? _pickupAddress
        : _order.dropoffAddressSingleLine;
    final (String phaseLabel, RiderStatusPillTone phaseTone) = _phaseChrome;
    final String? shopPhone = ref
        .watch(vendorPhoneProvider(_order.vendorId))
        .valueOrNull;

    ref.listen<LatLng?>(riderTripMapPositionProvider, (_, LatLng? pos) {
      _syncAtCustomerProximity(pos);
    });
    _measureSheetAfterFrame();

    // Top chrome is a fixed single row — no need to measure it like the
    // sheet, which changes height with the collect-amount card.
    final double topChromePadding = MediaQuery.paddingOf(context).top + 68;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RiderLiveTripMap(
            phase: _phase,
            vendorPosition: _vendorPosition,
            customerPosition: _customerPosition,
            vendorTitle: _order.storeName,
            customerTitle: 'Customer',
            topPadding: topChromePadding,
            bottomPadding: _sheetHeight + 16,
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: <Widget>[
                  RiderMapChrome(
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
                  const SizedBox(width: 10),
                  RiderStatusPill(
                    label: phaseLabel,
                    tone: phaseTone,
                    compact: true,
                  ),
                  const Spacer(),
                  RiderMapChrome(
                    padding: EdgeInsets.zero,
                    borderRadius: 99,
                    onTap: () =>
                        ref.invalidate(riderOrderDetailProvider(_order.id)),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.refresh_rounded,
                        color: cs.onSurface,
                        size: 22,
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
            child: ValueListenableBuilder<double>(
              valueListenable: _pathTracker.traveledKmListenable,
              builder: (BuildContext context, double traveledKm, _) {
                // Show what to collect throughout the customer leg, not just
                // at the final confirm — actual-trip fee is live from GPS km,
                // fixed fee is known up front. Prepaid orders show a separate
                // "nothing to collect" note instead (see onCallShop card).
                final bool onCustomerLeg = _phase.isCustomerLeg;
                final int? liveFee = !onCustomerLeg
                    ? null
                    : _order.usesActualTripFee
                    ? DeliveryPricing.feeLkrForActualTripKm(traveledKm)
                    : _order.deliveryFeeLkr;
                final int? liveCollect =
                    (liveFee == null || _order.isPrepaidOnline)
                    ? null
                    : _order.collectAmountLkr(estimatedDeliveryFeeLkr: liveFee);
                return KeyedSubtree(
                  key: _sheetKey,
                  child: RiderTripBottomPanel(
                    order: _order,
                    phase: _phase,
                    vendorPosition: _vendorPosition,
                    customerPosition: _customerPosition,
                    pickupAddress: _pickupAddress,
                    busy: _busy,
                    liveTraveledKm:
                        _order.usesActualTripFee && _phase.isCustomerLeg
                        ? traveledKm
                        : null,
                    liveDeliveryFeeLkr: liveFee,
                    liveCollectLkr: liveCollect,
                    showPrepaidNote: onCustomerLeg && _order.isPrepaidOnline,
                    onOrderPickedUp: _onOrderPickedUp,
                    onDelivered: _onDelivered,
                    onOpenMaps: () => _openMaps(mapsAddress),
                    onCallShop: (shopPhone != null && shopPhone.isNotEmpty)
                        ? _callShop
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
