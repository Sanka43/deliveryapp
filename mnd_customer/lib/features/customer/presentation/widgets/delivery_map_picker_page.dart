import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_pick_result.dart';

/// Default map center (Colombo area) when location is unavailable.
const LatLng _kDefaultMapCenter = LatLng(6.9271, 79.8612);

bool isDeliveryMapPickerSupported() {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Full-screen map: pan to move the pin (map center). Confirms with reverse geocode.
class DeliveryMapPickerPage extends StatefulWidget {
  const DeliveryMapPickerPage({super.key});

  static Future<DeliveryMapPickResult?> pick(BuildContext context) {
    if (!isDeliveryMapPickerSupported()) {
      return Future<DeliveryMapPickResult?>.value();
    }
    return Navigator.of(context).push<DeliveryMapPickResult>(
      MaterialPageRoute<DeliveryMapPickResult>(
        builder: (BuildContext context) => const DeliveryMapPickerPage(),
      ),
    );
  }

  @override
  State<DeliveryMapPickerPage> createState() => _DeliveryMapPickerPageState();
}

class _DeliveryMapPickerPageState extends State<DeliveryMapPickerPage> {
  GoogleMapController? _mapController;
  LatLng _mapCenter = _kDefaultMapCenter;
  bool _loadingGeocode = false;
  bool _locating = false;

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
              content:
                  Text('Please enable location services to use live location.'),
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
                    'Location permission is required to use your position.')),
          );
        }
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 12),
        ),
      ).onError<TimeoutException>((_, __) async {
        final Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return lastKnown;
        }
        throw Exception('Location request timed out. Try again.');
      });
      final LatLng target = LatLng(position.latitude, position.longitude);
      setState(() => _mapCenter = target);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
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
      final DeliveryMapPickResult result = _resultFromPlacemarks(
        marks,
        _mapCenter,
      );
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not resolve address: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingGeocode = false);
      }
    }
  }

  static DeliveryMapPickResult _resultFromPlacemarks(
    List<Placemark> marks,
    LatLng coordinates,
  ) {
    if (marks.isEmpty) {
      return DeliveryMapPickResult(
        line1:
            '${coordinates.latitude.toStringAsFixed(5)}, ${coordinates.longitude.toStringAsFixed(5)}',
        line2: '',
        city: 'Unknown area',
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
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
    if (city.isEmpty) {
      city = 'Unknown area';
    }

    final String postal = (p.postalCode ?? '').trim();
    final String line2 = postal.isNotEmpty ? 'Postal $postal' : '';

    return DeliveryMapPickResult(
      line1: line1,
      line2: line2,
      city: city,
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin delivery location'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _mapCenter,
              zoom: 16,
            ),
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
              child: Icon(
                Icons.location_pin,
                size: 48,
                color: Color(0xFFE53935),
              ),
            ),
          ),
          if (_loadingGeocode)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            right: AppSpacing.md,
            bottom: 100,
            child: FloatingActionButton.small(
              heroTag: 'map_my_location',
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
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: SafeArea(
              child: FilledButton.icon(
                onPressed: _loadingGeocode ? null : _confirm,
                icon: const Icon(Icons.check),
                label: const Text('Use this location'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
