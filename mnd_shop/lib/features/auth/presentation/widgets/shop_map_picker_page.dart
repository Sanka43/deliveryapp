import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_map_pick_result.dart';

/// Default center (Colombo) when opening the picker.
const LatLng kDefaultShopMapCenter = LatLng(6.9271, 79.8612);

bool isShopMapPickerSupported() {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Full-screen map: pan to move the pin (fixed center icon). Confirms with reverse geocode.
class ShopMapPickerPage extends StatefulWidget {
  const ShopMapPickerPage({
    super.key,
    this.initialCenter = kDefaultShopMapCenter,
  });

  final LatLng initialCenter;

  static Future<ShopMapPickResult?> open(
    BuildContext context, {
    LatLng? initialCenter,
  }) {
    if (!isShopMapPickerSupported()) {
      return Future<ShopMapPickResult?>.value();
    }
    final LatLng start = initialCenter ?? kDefaultShopMapCenter;
    return Navigator.of(context).push<ShopMapPickResult>(
      MaterialPageRoute<ShopMapPickResult>(
        builder: (BuildContext context) =>
            ShopMapPickerPage(initialCenter: start),
      ),
    );
  }

  @override
  State<ShopMapPickerPage> createState() => _ShopMapPickerPageState();
}

class _ShopMapPickerPageState extends State<ShopMapPickerPage> {
  GoogleMapController? _mapController;
  late LatLng _mapCenter;
  bool _loadingGeocode = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _mapCenter = widget.initialCenter;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Turn on location services to use your current position.',
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is needed to jump to your position.',
              ),
            ),
          );
        }
        return;
      }

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } on TimeoutException {
        final Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          position = lastKnown;
        } else {
          throw Exception('Location request timed out. Try again.');
        }
      }
      final LatLng target = LatLng(position.latitude, position.longitude);
      setState(() => _mapCenter = target);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                e,
                fallback: 'Could not get location. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _confirm() async {
    setState(() => _loadingGeocode = true);
    try {
      final List<Placemark> marks = await placemarkFromCoordinates(
        _mapCenter.latitude,
        _mapCenter.longitude,
      );
      final ShopMapPickResult result = _resultFromPlacemarks(marks, _mapCenter);
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop(
          ShopMapPickResult(
            latitude: _mapCenter.latitude,
            longitude: _mapCenter.longitude,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingGeocode = false);
      }
    }
  }

  static ShopMapPickResult _resultFromPlacemarks(
    List<Placemark> marks,
    LatLng coordinates,
  ) {
    if (marks.isEmpty) {
      return ShopMapPickResult(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        suggestedAddressLine:
            '${coordinates.latitude.toStringAsFixed(5)}, ${coordinates.longitude.toStringAsFixed(5)}',
        suggestedCity: '',
      );
    }
    final Placemark p = marks.first;

    final String street = (p.street ?? '').trim();
    final String thoroughfare = (p.thoroughfare ?? '').trim();
    final String name = (p.name ?? '').trim();
    final String sub = (p.subThoroughfare ?? '').trim();

    String line1;
    if (street.isNotEmpty) {
      line1 = street;
    } else {
      final List<String> parts = <String>[
        if (sub.isNotEmpty) sub,
        if (thoroughfare.isNotEmpty) thoroughfare,
        if (name.isNotEmpty && name != thoroughfare) name,
      ];
      line1 = parts.isNotEmpty
          ? parts.join(', ')
          : '${coordinates.latitude.toStringAsFixed(5)}, ${coordinates.longitude.toStringAsFixed(5)}';
    }

    String city =
        (p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? '')
            .trim();

    return ShopMapPickResult(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      suggestedAddressLine: line1,
      suggestedCity: city,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FF),
      appBar: AppBar(
        title: const Text('Pin shop location'),
        centerTitle: false,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _mapCenter, zoom: 16),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            onMapCreated: (GoogleMapController c) => _mapController = c,
            onCameraMove: (CameraPosition position) {
              _mapCenter = position.target;
            },
          ),
          const IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.location_pin, size: 50, color: Color(0xFFE53935)),
                  SizedBox(height: 18),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            top: 12,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.place_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Move the map and keep the pin centered.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_loadingGeocode)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton.small(
              heroTag: 'shop_map_my_location',
              onPressed: _locating ? null : _goToMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FilledButton.icon(
                onPressed: _loadingGeocode ? null : _confirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: const Color(0xFF0F52CC),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 6,
                  shadowColor: Colors.black.withValues(alpha: 0.22),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('Use this pin location'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
