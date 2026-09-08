import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/utils/map_platform_support.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/maps_proxy_client.dart';
import 'package:mnd_delivery_app/core/utils/placemark_address_utils.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/widgets/map_unavailable_banner.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/place_autocomplete_field.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_pick_result.dart';

/// Default map center (Colombo area) when location is unavailable.
const LatLng _kDefaultMapCenter = LatLng(6.9271, 79.8612);

bool isDeliveryMapPickerSupported() => isGoogleMapsSupported();

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

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey<PlaceAutocompleteFieldState> _searchFieldKey =
      GlobalKey<PlaceAutocompleteFieldState>();

  /// The Places Autocomplete suggestion the user last picked, if the map
  /// hasn't been moved since — [_confirm] uses its name/label directly
  /// instead of reverse-geocoding the pin when this is set. Cleared by any
  /// user-driven camera move (see `onCameraMoveStarted`), since moving the
  /// pin means they want a different point.
  PlaceDetailsResult? _selectedPlace;

  /// Set right before a programmatic `animateCamera` call so the
  /// `onCameraMoveStarted` callback it triggers doesn't mistake that for a
  /// user drag and clear [_selectedPlace].
  bool _ignoreNextCameraMoveStart = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _onPlaceSelected(PlaceDetailsResult details) async {
    final LatLng target = LatLng(details.lat, details.lng);
    _ignoreNextCameraMoveStart = true;
    setState(() {
      _selectedPlace = details;
      _mapCenter = target;
    });
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, 16),
    );
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          showMndSnackBar(
              context, 'Please enable location services to use live location.',
              variant: MndSnackBarVariant.warning);
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
          showMndSnackBar(
              context, 'Location permission is required to use your position.',
              variant: MndSnackBarVariant.warning);
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
      _ignoreNextCameraMoveStart = true;
      setState(() {
        _selectedPlace = null;
        _mapCenter = target;
      });
      _searchFieldKey.currentState?.clearHits();
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
    } catch (e) {
      if (mounted) {
        showMndSnackBar(
          context,
          userFacingError(
            e,
            fallback: 'Could not get your location. Please try again.',
          ),
          variant: MndSnackBarVariant.error,
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
      final PlaceDetailsResult? selected = _selectedPlace;
      if (selected != null) {
        // The map hasn't moved since a search suggestion was picked — use
        // its name/address directly instead of reverse-geocoding the pin.
        final List<String> parts = selected.label
            .split(',')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList();
        final DeliveryMapPickResult result = DeliveryMapPickResult(
          line1: selected.name.isNotEmpty
              ? selected.name
              : (parts.isNotEmpty ? parts.first : selected.label),
          line2: '',
          city: parts.length > 1 ? parts[parts.length - 2] : '',
          latitude: selected.lat,
          longitude: selected.lng,
          placeName: selected.name.isEmpty ? null : selected.name,
        );
        if (mounted) {
          Navigator.of(context).pop(result);
        }
        return;
      }
      DeliveryMapPickResult? result;
      // A named business/landmark right at the pin (e.g. "Pizza Hut -
      // Badulla") reads far better than a generic street address, and is the
      // only way to avoid a bare Plus Code in areas with no proper address
      // data — same reasoning that shows a label on Google Maps' own pin.
      final NearestPlaceResult? nearest = await findNearestPlaceViaFunction(
        _mapCenter.latitude,
        _mapCenter.longitude,
      );
      if (nearest != null) {
        final List<String> parts = nearest.formattedAddress
            .split(',')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList();
        result = DeliveryMapPickResult(
          line1: nearest.name,
          line2: '',
          city: parts.length > 1 ? parts[parts.length - 2] : '',
          latitude: _mapCenter.latitude,
          longitude: _mapCenter.longitude,
          placeName: nearest.name,
        );
      } else if (kIsWeb) {
        // `geocoding` has no web implementation — use the Cloud Function
        // proxy instead (Google's Geocoding REST API blocks direct browser
        // calls).
        final String? label = await reverseGeocodeViaFunction(
          _mapCenter.latitude,
          _mapCenter.longitude,
        );
        if (label != null) {
          final List<String> parts = label
              .split(',')
              .map((String s) => s.trim())
              .where((String s) => s.isNotEmpty)
              .toList();
          result = DeliveryMapPickResult(
            line1: parts.isNotEmpty ? parts.first : label,
            line2: '',
            city: parts.length > 1 ? parts[parts.length - 2] : '',
            latitude: _mapCenter.latitude,
            longitude: _mapCenter.longitude,
          );
        }
      } else {
        try {
          final List<Placemark> marks = await placemarkFromCoordinates(
            _mapCenter.latitude,
            _mapCenter.longitude,
          );
          result = buildDeliveryAddressFromPlacemarks(marks, _mapCenter);
        } catch (_) {}
      }
      // Reverse geocoding isn't always available — fall back to coordinates
      // rather than blocking the user from confirming a pin they can
      // clearly see on the map.
      result ??= DeliveryMapPickResult(
        line1:
            '${_mapCenter.latitude.toStringAsFixed(5)}, ${_mapCenter.longitude.toStringAsFixed(5)}',
        line2: '',
        city: '',
        latitude: _mapCenter.latitude,
        longitude: _mapCenter.longitude,
      );
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingGeocode = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Without the Maps JS script the map is a blank grey box: panning it
    // does nothing and "Confirm" would hand back the default Colombo
    // centre as if the customer had picked it. Say why instead.
    if (MapUnavailableBanner.shouldShow) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: mndPageAppBar(title: 'Pin delivery location'),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const MapUnavailableBanner(),
              const SizedBox(height: AppSpacing.md),
              Text(
                'You can still type your address by hand on the previous '
                'screen.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mndPageAppBar(title: 'Pin delivery location'),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
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
                  onCameraMoveStarted: () {
                    if (_ignoreNextCameraMoveStart) {
                      _ignoreNextCameraMoveStart = false;
                      return;
                    }
                    if (_selectedPlace != null) {
                      setState(() => _selectedPlace = null);
                    }
                  },
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
                  top: AppSpacing.sm,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: PlaceAutocompleteField(
                    key: _searchFieldKey,
                    controller: _searchController,
                    focusNode: _searchFocus,
                    hintText: 'Search delivery location',
                    biasCenter: () => _mapCenter,
                    onPlaceSelected: _onPlaceSelected,
                  ),
                ),
                Positioned(
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
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
              ],
            ),
          ),
          Material(
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Move the map to place the pin on your drop-off',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: _loadingGeocode ? null : _confirm,
                      icon: _loadingGeocode
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        _loadingGeocode ? 'Resolving…' : 'Use this location',
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
