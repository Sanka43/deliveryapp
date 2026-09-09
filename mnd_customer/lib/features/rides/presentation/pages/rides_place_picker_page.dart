import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/utils/maps_proxy_client.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/widgets/place_autocomplete_field.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_place.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_map_support.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_theme.dart';
import 'package:mnd_delivery_app/features/rides/presentation/widgets/rides_map_controls.dart';

enum RidesPlacePickerMode { pickup, dropoff, stop }

/// Full-screen map + search to choose a pickup or drop-off place.
class RidesPlacePickerPage extends StatefulWidget {
  const RidesPlacePickerPage({
    super.key,
    required this.mode,
    this.initial,
  });

  final RidesPlacePickerMode mode;
  final RidePlace? initial;

  static Future<RidePlace?> open(
    BuildContext context, {
    required RidesPlacePickerMode mode,
    RidePlace? initial,
  }) {
    return Navigator.of(context).push<RidePlace>(
      MaterialPageRoute<RidePlace>(
        builder: (BuildContext context) => RidesPlacePickerPage(
          mode: mode,
          initial: initial,
        ),
      ),
    );
  }

  @override
  State<RidesPlacePickerPage> createState() => _RidesPlacePickerPageState();
}

class _RidesPlacePickerPageState extends State<RidesPlacePickerPage> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GlobalKey<PlaceAutocompleteFieldState> _searchFieldKey =
      GlobalKey<PlaceAutocompleteFieldState>();

  late LatLng _mapCenter;
  double _zoom = 15;
  bool _locating = false;
  bool _confirming = false;

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

  bool get _isPickup => widget.mode == RidesPlacePickerMode.pickup;
  bool get _isStop => widget.mode == RidesPlacePickerMode.stop;

  String get _pinMode => switch (widget.mode) {
        RidesPlacePickerMode.pickup => 'pickup',
        RidesPlacePickerMode.dropoff => 'dropoff',
        RidesPlacePickerMode.stop => 'stop',
      };

  Color get _accent => switch (widget.mode) {
        RidesPlacePickerMode.pickup => const Color(RidesColors.pickupGreen),
        RidesPlacePickerMode.dropoff => const Color(RidesColors.dropoffRed),
        RidesPlacePickerMode.stop => const Color(RidesColors.stopAmber),
      };

  String get _title => switch (widget.mode) {
        RidesPlacePickerMode.pickup => 'Set pick-up',
        RidesPlacePickerMode.dropoff => 'Set drop-off',
        RidesPlacePickerMode.stop => 'Add a stop',
      };

  @override
  void initState() {
    super.initState();
    final RidePlace? initial = widget.initial;
    _mapCenter = initial != null
        ? LatLng(initial.lat, initial.lng)
        : kRidesDefaultCenter;
    if (initial != null && initial.label.isNotEmpty) {
      _searchController.text = initial.label;
    }
  }

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
      _zoom = 16;
    });
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, 16),
    );
  }

  Future<void> _zoomBy(double delta) async {
    final double next = (_zoom + delta).clamp(3.0, 20.0);
    setState(() => _zoom = next);
    await _mapController?.animateCamera(CameraUpdate.zoomTo(next));
  }

  Future<void> _goToLiveLocation() async {
    setState(() => _locating = true);
    try {
      final PlaceResolveResult result = await resolveCurrentPlaceResult();
      final RidePlace? place = result.place;
      if (!mounted) {
        return;
      }
      if (place == null) {
        showMndSnackBar(
          context,
          locationUnavailableMessage(
            permissionDenied: result.permissionDenied,
          ),
          variant: MndSnackBarVariant.warning,
          duration: const Duration(seconds: 6),
        );
        return;
      }
      final LatLng target = LatLng(place.lat, place.lng);
      _ignoreNextCameraMoveStart = true;
      setState(() {
        _selectedPlace = null;
        _mapCenter = target;
        _zoom = 16;
        _searchController.text = place.label;
      });
      _searchFieldKey.currentState?.clearHits();
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    try {
      final bool mapOk = isRidesMapSupported();
      final PlaceDetailsResult? selected = _selectedPlace;
      RidePlace place;
      if (selected != null) {
        // The map hasn't moved since a search suggestion was picked — use
        // its name/label directly instead of reverse-geocoding the pin.
        place = RidePlace(
          lat: selected.lat,
          lng: selected.lng,
          label: selected.label,
          placeId: selected.placeId,
          name: selected.name.isEmpty ? null : selected.name,
        );
      } else if (mapOk) {
        place = await reverseGeocodeRidePlace(_mapCenter);
      } else {
        if (mounted) {
          showMndSnackBar(
            context,
            'Search and select a place first.',
            variant: MndSnackBarVariant.warning,
          );
        }
        return;
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(place);
    } catch (e) {
      if (mounted) {
        showMndSnackBar(
          context,
          userFacingError(
            e,
            fallback: 'Could not resolve address. Please try again.',
          ),
          variant: MndSnackBarVariant.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _confirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool mapOk = isRidesMapSupported();

    return Scaffold(
      body: Stack(
        children: <Widget>[
          if (mapOk)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _mapCenter,
                zoom: _zoom,
              ),
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
                _zoom = position.zoom;
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            )
          else
            Container(color: const Color(0xFFE8EEF6)),
          if (mapOk)
            RidesMapCenterPin(mode: _pinMode),
          if (_confirming)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PlaceAutocompleteField(
                          key: _searchFieldKey,
                          controller: _searchController,
                          focusNode: _searchFocus,
                          hintText: _isPickup
                              ? 'Search pick-up location'
                              : _isStop
                                  ? 'Search stop location'
                                  : 'Search drop-off location',
                          accentColor: _accent,
                          biasCenter: () => _mapCenter,
                          onPlaceSelected: _onPlaceSelected,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (mapOk)
            RidesMapControls(
              bottomInset: 100 + MediaQuery.paddingOf(context).bottom,
              locating: _locating,
              onZoomIn: () => _zoomBy(1),
              onZoomOut: () => _zoomBy(-1),
              onMyLocation: _goToLiveLocation,
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _confirming ? null : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: RidesColors.accentBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      _isPickup
                          ? 'Confirm pick-up'
                          : _isStop
                              ? 'Confirm stop'
                              : 'Confirm drop-off',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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
