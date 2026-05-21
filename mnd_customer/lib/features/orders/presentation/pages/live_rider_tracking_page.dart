import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_detail.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/rider_live_location.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_timeline.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/rider_live_location_provider.dart';
import 'package:mnd_delivery_app/features/orders/presentation/widgets/rider_eta_countdown.dart';

const LatLng _kDefaultCenter = LatLng(6.9271, 79.8612);

class LiveRiderTrackingPage extends ConsumerStatefulWidget {
  const LiveRiderTrackingPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<LiveRiderTrackingPage> createState() => _LiveRiderTrackingPageState();
}

class _LiveRiderTrackingPageState extends ConsumerState<LiveRiderTrackingPage> {
  GoogleMapController? _map;
  bool _didInitialBounds = false;
  /// When true, map camera follows [RiderLiveLocation] stream updates.
  bool _followRider = true;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  bool get _mapSupported {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Set<Marker> _buildMarkers({
    required RiderLiveLocation? rider,
    required double? dropLat,
    required double? dropLng,
  }) {
    final Set<Marker> out = <Marker>{};
    if (rider != null) {
      out.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: LatLng(rider.latitude, rider.longitude),
          rotation: rider.heading ?? 0,
          flat: (rider.heading != null),
          infoWindow: const InfoWindow(title: 'Rider'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
    if (dropLat != null && dropLng != null) {
      out.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(dropLat, dropLng),
          infoWindow: const InfoWindow(title: 'Your address'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
    return out;
  }

  Set<Polyline> _buildPolylines({
    required RiderLiveLocation? rider,
    required double? dropLat,
    required double? dropLng,
  }) {
    if (rider == null || dropLat == null || dropLng == null) {
      return <Polyline>{};
    }
    return <Polyline>{
      Polyline(
        polylineId: const PolylineId('rider_to_dropoff'),
        color: AppColors.primaryBlue.withValues(alpha: 0.85),
        width: 4,
        points: <LatLng>[
          LatLng(rider.latitude, rider.longitude),
          LatLng(dropLat, dropLng),
        ],
      ),
    };
  }

  Future<void> _fitToMarkers({
    required RiderLiveLocation? rider,
    required double? dropLat,
    required double? dropLng,
  }) async {
    final GoogleMapController? c = _map;
    if (c == null) {
      return;
    }
    if (rider != null && dropLat != null && dropLng != null) {
      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          rider.latitude < dropLat ? rider.latitude : dropLat,
          rider.longitude < dropLng ? rider.longitude : dropLng,
        ),
        northeast: LatLng(
          rider.latitude > dropLat ? rider.latitude : dropLat,
          rider.longitude > dropLng ? rider.longitude : dropLng,
        ),
      );
      await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      return;
    }
    if (rider != null) {
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(rider.latitude, rider.longitude), 15),
      );
    } else if (dropLat != null && dropLng != null) {
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(dropLat, dropLng), 15),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CustomerOrderDetail?> orderState =
        ref.watch(orderDetailStreamProvider(widget.orderId));
    final CustomerOrderDetail? detail = orderState.asData?.value;
    final String riderKey = detail?.riderId?.trim() ?? '';
    final AsyncValue<RiderLiveLocation?> riderState =
        ref.watch(riderLiveLocationStreamProvider(riderKey));
    final RiderLiveLocation? rider = riderState.asData?.value;

    ref.listen<AsyncValue<RiderLiveLocation?>>(
      riderLiveLocationStreamProvider(riderKey),
      (AsyncValue<RiderLiveLocation?>? previous, AsyncValue<RiderLiveLocation?> next) {
        if (!_mapSupported) {
          return;
        }
        final GoogleMapController? c = _map;
        final RiderLiveLocation? r = next.asData?.value;
        if (c == null) {
          return;
        }
        if (_didInitialBounds &&
            _followRider &&
            r != null) {
          c.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(r.latitude, r.longitude), 16),
          );
        }
        if (_didInitialBounds) {
          return;
        }
        final CustomerOrderDetail? d =
            ref.read(orderDetailStreamProvider(widget.orderId)).asData?.value;
        if (r == null || d == null) {
          return;
        }
        final double? dl = d.dropoffLatitude;
        final double? dg = d.dropoffLongitude;
        if (dl == null || dg == null) {
          return;
        }
        _didInitialBounds = true;
        _fitToMarkers(rider: r, dropLat: dl, dropLng: dg);
      },
    );

    if (orderState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (orderState.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live tracking')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Could not load order.\n${orderState.error}'),
          ),
        ),
      );
    }
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live tracking')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text('Order not found or you do not have access.'),
          ),
        ),
      );
    }

    final double? dropLat = detail.dropoffLatitude;
    final double? dropLng = detail.dropoffLongitude;
    final bool assigned = riderKey.isNotEmpty;
    final bool activeMap = OrderTimelineLogic.isActiveForLiveRiderMap(detail.statusRaw);

    final Widget mapOrFallback = _mapSupported
        ? GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _kDefaultCenter,
              zoom: 13,
            ),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            markers: _buildMarkers(rider: rider, dropLat: dropLat, dropLng: dropLng),
            polylines: _buildPolylines(rider: rider, dropLat: dropLat, dropLng: dropLng),
            onMapCreated: (GoogleMapController controller) {
              _map = controller;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                if (rider != null &&
                    dropLat != null &&
                    dropLng != null &&
                    !_didInitialBounds) {
                  _didInitialBounds = true;
                  _fitToMarkers(rider: rider, dropLat: dropLat, dropLng: dropLng);
                } else if (!_didInitialBounds) {
                  _fitToMarkers(rider: rider, dropLat: dropLat, dropLng: dropLng);
                }
              });
            },
          )
        : Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                kIsWeb
                    ? 'Live map is available in the Android and iOS apps.'
                    : 'Map is not supported on this platform.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live tracking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: <Widget>[
          if (assigned && rider != null && _mapSupported)
            IconButton(
              tooltip: _followRider ? 'Stop following rider' : 'Follow rider',
              onPressed: () {
                final RiderLiveLocation loc = rider;
                setState(() => _followRider = !_followRider);
                if (_followRider) {
                  _map?.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(loc.latitude, loc.longitude),
                      16,
                    ),
                  );
                }
              },
              icon: Icon(
                _followRider ? Icons.gps_fixed : Icons.gps_not_fixed,
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: mapOrFallback),
          Material(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    detail.storeName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tracking ${detail.referenceForDisplay}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                  ),
                  if (assigned &&
                      rider != null &&
                      dropLat != null &&
                      dropLng != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    RiderEtaCountdown(
                      rider: rider,
                      dropLat: dropLat,
                      dropLng: dropLng,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  if (!assigned)
                    Text(
                      activeMap
                          ? 'A rider will appear here once someone is assigned.'
                          : 'Tracking is only active while your order is on the way.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else if (riderState.isLoading)
                    const LinearProgressIndicator(minHeight: 3)
                  else if (rider == null)
                    Text(
                      'Waiting for rider location updates…',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black87,
                          ),
                    )
                  else
                    Text(
                      rider.updatedAt != null
                          ? 'Last location update · ${_formatTime(rider.updatedAt!)}'
                          : 'Receiving live location updates.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  if (dropLat == null || dropLng == null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        'Delivery pin not set for this order — only the rider shows on the map.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _mapSupported && assigned && rider != null
          ? FloatingActionButton.small(
              onPressed: () => _fitToMarkers(
                rider: rider,
                dropLat: dropLat,
                dropLng: dropLng,
              ),
              child: const Icon(Icons.fit_screen),
            )
          : null,
    );
  }

  static String _formatTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }
}
