import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/utils/maps_proxy_client.dart';
import 'package:mnd_delivery_app/core/utils/placemark_address_utils.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
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

  late LatLng _mapCenter;
  double _zoom = 15;
  bool _locating = false;
  bool _confirming = false;
  bool _searching = false;
  List<_SearchHit> _hits = const <_SearchHit>[];
  Timer? _debounce;

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
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onSearchChanged(String raw) {
    _debounce?.cancel();
    final String q = raw.trim();
    if (q.length < 3) {
      setState(() {
        _hits = const <_SearchHit>[];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _runSearch(q);
    });
  }

  Future<void> _runSearch(String query) async {
    if (kIsWeb) {
      // `geocoding` has no web implementation — use the Cloud Function
      // proxy instead (Google's Geocoding REST API blocks direct browser
      // calls).
      final List<GeoSearchHit> webHits = await geocodeSearchViaFunction(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _hits = webHits
            .map(
              (GeoSearchHit h) => _SearchHit(
                label: h.label,
                latLng: LatLng(h.lat, h.lng),
              ),
            )
            .toList(growable: false);
        _searching = false;
      });
      return;
    }
    try {
      // Prefer Sri Lanka results for MND.
      final String scoped = query.toLowerCase().contains('sri lanka')
          ? query
          : '$query, Sri Lanka';
      final List<Location> locations = await locationFromAddress(scoped);
      final List<_SearchHit> hits = <_SearchHit>[];
      for (final Location loc in locations.take(6)) {
        String label =
            '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}';
        try {
          final List<Placemark> marks = await placemarkFromCoordinates(
            loc.latitude,
            loc.longitude,
          );
          final String composed = formatBestPlacemarkLabel(marks);
          if (composed.isNotEmpty) {
            label = composed;
          }
        } catch (_) {}
        hits.add(
          _SearchHit(
            label: label,
            latLng: LatLng(loc.latitude, loc.longitude),
          ),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _hits = hits;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hits = const <_SearchHit>[];
        _searching = false;
      });
    }
  }

  Future<void> _selectHit(_SearchHit hit) async {
    _searchFocus.unfocus();
    setState(() {
      _hits = const <_SearchHit>[];
      _mapCenter = hit.latLng;
      _searchController.text = hit.label;
      _zoom = 16;
    });
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(hit.latLng, 16),
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
      setState(() {
        _mapCenter = target;
        _zoom = 16;
        _searchController.text = place.label;
        _hits = const <_SearchHit>[];
      });
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
      RidePlace place;
      if (mapOk) {
        place = await reverseGeocodeRidePlace(_mapCenter);
      } else {
        final String q = _searchController.text.trim();
        if (q.length < 3) {
          if (mounted) {
            showMndSnackBar(context, 'Search for a place first.', variant: MndSnackBarVariant.warning);
          }
          return;
        }
        final List<Location> locations = await locationFromAddress(
          q.toLowerCase().contains('sri lanka') ? q : '$q, Sri Lanka',
        );
        if (locations.isEmpty) {
          if (mounted) {
            showMndSnackBar(context, 'No matching place found.', variant: MndSnackBarVariant.warning);
          }
          return;
        }
        place = await reverseGeocodeRidePlace(
          LatLng(locations.first.latitude, locations.first.longitude),
        );
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
                        child: Material(
                          elevation: 3,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            onSubmitted: (String v) {
                              if (v.trim().length >= 3) {
                                _runSearch(v.trim());
                              }
                            },
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: _isPickup
                                  ? 'Search pick-up location'
                                  : _isStop
                                      ? 'Search stop location'
                                      : 'Search drop-off location',
                              prefixIcon: Icon(Icons.search, color: _accent),
                              suffixIcon: _searching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : (_searchController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _hits = const <_SearchHit>[];
                                            });
                                          },
                                        )),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 14,
                              ),
                            ),
                          ),
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
                  if (_hits.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _hits.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int i) {
                          final _SearchHit hit = _hits[i];
                          return ListTile(
                            leading: Icon(Icons.place_outlined, color: _accent),
                            title: Text(
                              hit.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectHit(hit),
                          );
                        },
                      ),
                    ),
                  ],
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

class _SearchHit {
  const _SearchHit({required this.label, required this.latLng});

  final String label;
  final LatLng latLng;
}
