import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/utils/maps_proxy_client.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';

/// Search box + debounced Places Autocomplete (New) dropdown, shared by the
/// rides and delivery location pickers. Owns the network/session-token
/// plumbing; the parent only reacts to [onPlaceSelected] with a resolved
/// name/label/lat/lng — it stays in charge of what happens to the map/pin.
class PlaceAutocompleteField extends StatefulWidget {
  const PlaceAutocompleteField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onPlaceSelected,
    required this.biasCenter,
    this.accentColor,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<PlaceDetailsResult> onPlaceSelected;

  /// Current map center, used to bias suggestions toward that area.
  final LatLng Function() biasCenter;

  final Color? accentColor;

  @override
  State<PlaceAutocompleteField> createState() =>
      PlaceAutocompleteFieldState();
}

class PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  List<PlaceAutocompleteHit> _hits = const <PlaceAutocompleteHit>[];
  bool _searching = false;
  Timer? _debounce;
  String _sessionToken = newPlacesSessionToken();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Clears the suggestions dropdown — e.g. after the parent handles a
  /// selection made some other way (live-location button, pin drag).
  void clearHits() {
    if (_hits.isNotEmpty) {
      setState(() => _hits = const <PlaceAutocompleteHit>[]);
    }
  }

  void _onChanged(String raw) {
    _debounce?.cancel();
    final String q = raw.trim();
    if (q.length < 3) {
      setState(() {
        _hits = const <PlaceAutocompleteHit>[];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () => _runSearch(q));
  }

  Future<void> _runSearch(String query) async {
    final LatLng center = widget.biasCenter();
    final List<PlaceAutocompleteHit> hits = await placeAutocompleteViaFunction(
      query,
      _sessionToken,
      lat: center.latitude,
      lng: center.longitude,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _hits = hits;
      _searching = false;
    });
  }

  Future<void> _selectHit(PlaceAutocompleteHit hit) async {
    widget.focusNode.unfocus();
    setState(() {
      _hits = const <PlaceAutocompleteHit>[];
      _searching = true;
    });
    final PlaceDetailsResult? details = await placeDetailsViaFunction(
      hit.placeId,
      _sessionToken,
    );
    // Session closed by that details call — start a fresh one for the next
    // search interaction.
    _sessionToken = newPlacesSessionToken();
    if (!mounted) {
      return;
    }
    setState(() => _searching = false);
    if (details == null) {
      showMndSnackBar(
        context,
        'Could not load that place. Try again.',
        variant: MndSnackBarVariant.warning,
      );
      return;
    }
    widget.controller.text = details.label;
    widget.onPlaceSelected(details);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent =
        widget.accentColor ?? Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          elevation: 3,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            onChanged: _onChanged,
            onSubmitted: (String v) {
              if (v.trim().length >= 3) {
                _runSearch(v.trim());
              }
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: Icon(Icons.search, color: accent),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (widget.controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            widget.controller.clear();
                            setState(() {
                              _hits = const <PlaceAutocompleteHit>[];
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
                final PlaceAutocompleteHit hit = _hits[i];
                return ListTile(
                  leading: Icon(Icons.place_outlined, color: accent),
                  title: Text(
                    hit.primaryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: hit.secondaryText.isEmpty
                      ? null
                      : Text(
                          hit.secondaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  onTap: () => _selectHit(hit),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
