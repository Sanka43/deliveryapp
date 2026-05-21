import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_rider/core/services/maps/rider_maps_helper.dart';
import 'package:mnd_rider/core/services/rider_location_service.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/trip/domain/rider_trip_phase.dart';
import 'package:mnd_rider/features/trip/presentation/providers/rider_trip_tracking_provider.dart';
import 'package:mnd_rider/features/trip/presentation/widgets/rider_live_trip_map.dart';
import 'package:mnd_rider/features/trip/presentation/widgets/rider_trip_bottom_panel.dart';
import 'package:url_launcher/url_launcher.dart';

/// Live delivery tracking: map navigation, polylines, ETA, Firestore sync.
class RiderTripNavigationPage extends ConsumerStatefulWidget {
  const RiderTripNavigationPage({
    super.key,
    required this.order,
  });

  final RiderOrderDetail order;

  @override
  ConsumerState<RiderTripNavigationPage> createState() =>
      _RiderTripNavigationPageState();
}

class _RiderTripNavigationPageState extends ConsumerState<RiderTripNavigationPage> {
  late RiderTripPhase _phase;
  bool _busy = false;
  late final RiderLocationService _locationService;

  @override
  void initState() {
    super.initState();
    _locationService = ref.read(riderLocationServiceProvider);
    _phase = riderTripPhaseFromOrder(widget.order);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _locationService.setTripMode(true);
    });
  }

  @override
  void dispose() {
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

  Future<void> _openMaps(String address) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeQueryComponent(address)}&travelmode=driving',
    );
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || ok) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Google Maps')),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return false;
    }
    return true;
  }

  Future<void> _onArrivedAtStore() async {
    setState(() => _phase = RiderTripPhase.atVendor);
  }

  Future<void> _onOrderPickedUp() async {
    final bool ok = await _updateStatus('picked_up');
    if (!ok || !mounted) {
      return;
    }
    await _updateStatus('on_the_way');
    if (mounted) {
      setState(() => _phase = RiderTripPhase.navigateToCustomer);
    }
  }

  Future<void> _onDelivered() async {
    final bool ok = await _updateStatus('delivered');
    if (ok && mounted) {
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String mapsAddress = _phase.isVendorLeg
        ? _pickupAddress
        : _order.dropoffAddressSingleLine;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live delivery'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(riderOrderDetailProvider(_order.id)),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RiderLiveTripMap(
            phase: _phase,
            vendorPosition: _vendorPosition,
            customerPosition: _customerPosition,
            vendorTitle: _order.storeName,
            customerTitle: 'Customer',
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RiderTripBottomPanel(
              order: _order,
              phase: _phase,
              vendorPosition: _vendorPosition,
              customerPosition: _customerPosition,
              pickupAddress: _pickupAddress,
              busy: _busy,
              onArrivedAtStore: _onArrivedAtStore,
              onOrderPickedUp: _onOrderPickedUp,
              onDelivered: _onDelivered,
              onOpenMaps: () => _openMaps(mapsAddress),
            ),
          ),
        ],
      ),
    );
  }
}
