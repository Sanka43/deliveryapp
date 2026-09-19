import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/utils/map_platform_support.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/delivery_address_resolver.dart';
import 'package:mnd_delivery_app/core/utils/maps_proxy_client.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/widgets/map_unavailable_banner.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/place_autocomplete_field.dart';
import 'package:mnd_delivery_app/features/customer/data/saved_address.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/saved_addresses_provider.dart';
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
  void initState() {
    super.initState();
    // Rebuild whenever focus or text changes so the saved-addresses
    // dropdown can show/hide itself — see [_showSavedAddressDropdown].
    _searchFocus.addListener(_onSearchFocusOrTextChanged);
    _searchController.addListener(_onSearchFocusOrTextChanged);
  }

  void _onSearchFocusOrTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Saved addresses show as a dropdown right under the search bar the
  /// moment it's tapped (empty) — typing anything hides it in favour of the
  /// field's own Places Autocomplete results.
  bool get _showSavedAddressDropdown =>
      _searchFocus.hasFocus && _searchController.text.trim().isEmpty;

  @override
  void dispose() {
    _searchFocus.removeListener(_onSearchFocusOrTextChanged);
    _searchController.removeListener(_onSearchFocusOrTextChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Applies a saved address directly — skips the map/confirm step
  /// entirely, mirroring the one-tap convenience the checkout page's own
  /// saved-address chips used to offer before this row moved here.
  ///
  /// Works even when the saved address was never pinned on the map: it's
  /// returned with null coordinates, and the caller falls back to a flat
  /// delivery fee — same as picking an unpinned saved address always did.
  void _useSavedAddress(SavedAddress address) {
    Navigator.of(context).pop(
      DeliveryMapPickResult(
        line1: address.line1,
        line2: address.line2,
        city: address.city,
        latitude: address.latitude,
        longitude: address.longitude,
        phone: address.phone.isNotEmpty ? address.phone : null,
      ),
    );
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
      final DeliveryMapPickResult result =
          await resolveDeliveryAddressForPoint(_mapCenter);
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
          // Search bar takes the app bar's place — back button in the same
          // row instead of a separate title bar above it.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 3,
                          shadowColor: Colors.black26,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.arrow_back, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: PlaceAutocompleteField(
                            key: _searchFieldKey,
                            controller: _searchController,
                            focusNode: _searchFocus,
                            hintText: 'Search delivery location',
                            biasCenter: () => _mapCenter,
                            onPlaceSelected: _onPlaceSelected,
                          ),
                        ),
                      ],
                    ),
                    if (_showSavedAddressDropdown)
                      Consumer(
                        builder: (BuildContext context, WidgetRef ref, _) {
                          final AsyncValue<List<SavedAddress>> async =
                              ref.watch(savedAddressesStreamProvider);
                          final List<SavedAddress> saved =
                              async.valueOrNull ?? const <SavedAddress>[];
                          if (saved.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Material(
                              color: Colors.white,
                              elevation: 4,
                              borderRadius: BorderRadius.circular(14),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 260),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  itemCount: saved.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final SavedAddress a = saved[index];
                                    final String detail = <String>[
                                      a.line1,
                                      if (a.line2.isNotEmpty) a.line2,
                                      a.city,
                                    ]
                                        .where((String s) => s.isNotEmpty)
                                        .join(', ');
                                    return ListTile(
                                      leading: Icon(
                                        a.isDefault
                                            ? Icons.star_rounded
                                            : Icons.location_on_outlined,
                                        color: a.isDefault
                                            ? AppColors.warning
                                            : AppColors.primaryBlue,
                                      ),
                                      title: Text(
                                        a.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: detail.isEmpty
                                          ? null
                                          : Text(
                                              detail,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                      onTap: () => _useSavedAddress(a),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Floating, no card backdrop — the my-location button sits right
          // above the confirm button instead of a separate fixed bottom bar.
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    FloatingActionButton.small(
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
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(elevation: 4),
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
