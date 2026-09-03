import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/utils/map_platform_support.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/utils/maps_proxy_client.dart';
import 'package:mnd_delivery_app/core/utils/placemark_address_utils.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_pick_result.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_picker_page.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_place.dart';

const LatLng kRidesDefaultCenter = LatLng(6.9271, 79.8612);

bool isRidesMapSupported() => isGoogleMapsSupported();

/// Shown when live GPS location can't be resolved.
///
/// [permissionDenied] must only be true when the OS/browser permission check
/// itself came back denied — conflating that with a timed-out GPS fix (common
/// on a cold-start mobile browser location request) sent users who had
/// already granted permission off to a browser-settings screen with nothing
/// to fix there. On web, browsers never re-show the permission popup once a
/// site's Location permission has been blocked, so that case points them at
/// the browser's own site settings instead.
String locationUnavailableMessage({required bool permissionDenied}) {
  if (!permissionDenied) {
    return "Couldn't get your location — try again in a moment.";
  }
  if (kIsWeb) {
    return 'Location is blocked for this site. Open your browser menu → '
        'Site settings → Location → Allow, then reload the page.';
  }
  return 'Enable location to use live position.';
}

Future<RidePlace?> pickRidePlaceOnMap(BuildContext context) async {
  if (!isRidesMapSupported()) {
    return _promptAddressFallback(context);
  }
  final DeliveryMapPickResult? picked = await DeliveryMapPickerPage.pick(context);
  if (picked == null) {
    return null;
  }
  final String composed = <String>[
    picked.line1,
    picked.line2,
    picked.city,
  ]
      .map(cleanAddressPart)
      .where((String s) => s.isNotEmpty)
      .join(', ');
  return RidePlace(
    lat: picked.latitude,
    lng: picked.longitude,
    label: composed.isEmpty
        ? '${picked.latitude.toStringAsFixed(5)}, ${picked.longitude.toStringAsFixed(5)}'
        : composed,
  );
}

/// Outcome of a live-location resolve attempt — distinguishes a real
/// permission denial from every other failure (bad/no GPS fix, etc.) so
/// callers can pick the right [locationUnavailableMessage].
class LocationResolveResult {
  const LocationResolveResult._(this.position, this.permissionDenied);
  final Position? position;
  final bool permissionDenied;
}

/// GPS only — prefers last-known, then medium accuracy. No reverse geocode.
///
/// `permissionDenied` is set only when the actual [Geolocator.getCurrentPosition]
/// call throws [PermissionDeniedException] — never from
/// `checkPermission()`/`requestPermission()`'s return value. On web,
/// `geolocator_web`'s `requestPermission()` swallows every failure from its
/// internal probe call (no GPS signal, a bad fix, anything at all) and
/// reports `deniedForever` regardless of the real cause, so trusting that
/// return value wrongly sent users who had genuinely granted permission to a
/// browser-settings screen with nothing to fix. Reading the exception thrown
/// by the real fetch is the only reliable signal. A generous 15s timeout: a
/// cold-start GPS/network fix (first request after granting permission,
/// common on mobile web) can easily take longer than the 5s this used to
/// allow.
Future<LocationResolveResult> resolveCurrentPositionResult({
  bool allowLastKnown = true,
}) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return const LocationResolveResult._(null, true);
  }
  // Still run the standard check/request first — on web this is what
  // surfaces the native permission prompt while the browser hasn't decided
  // yet ('prompt' state); its return value just isn't trusted below.
  final LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    await Geolocator.requestPermission();
  }
  if (allowLastKnown) {
    try {
      final Position? last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return LocationResolveResult._(last, false);
      }
    } catch (_) {}
  }
  try {
    final Position pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LocationResolveResult._(pos, false);
  } on PermissionDeniedException {
    return const LocationResolveResult._(null, true);
  } catch (_) {
    return const LocationResolveResult._(null, false);
  }
}

Future<Position?> resolveCurrentPosition({bool allowLastKnown = true}) async {
  final LocationResolveResult result = await resolveCurrentPositionResult(
    allowLastKnown: allowLastKnown,
  );
  return result.position;
}

RidePlace ridePlaceFromPosition(Position pos, {String? label}) {
  return RidePlace(
    lat: pos.latitude,
    lng: pos.longitude,
    label: label ??
        '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
  );
}

/// Outcome of a live-place resolve attempt (position + reverse-geocoded
/// label), carrying the same [LocationResolveResult.permissionDenied] signal.
class PlaceResolveResult {
  const PlaceResolveResult._(this.place, this.permissionDenied);
  final RidePlace? place;
  final bool permissionDenied;
}

Future<PlaceResolveResult> resolveCurrentPlaceResult({
  bool allowLastKnown = true,
}) async {
  final LocationResolveResult result = await resolveCurrentPositionResult(
    allowLastKnown: allowLastKnown,
  );
  final Position? pos = result.position;
  if (pos == null) {
    return PlaceResolveResult._(null, result.permissionDenied);
  }
  final RidePlace place =
      await reverseGeocodeRidePlace(LatLng(pos.latitude, pos.longitude));
  return PlaceResolveResult._(place, false);
}

/// Full place with reverse-geocoded label. Uses last-known GPS when available.
Future<RidePlace?> resolveCurrentPlace({bool allowLastKnown = true}) async {
  final PlaceResolveResult result = await resolveCurrentPlaceResult(
    allowLastKnown: allowLastKnown,
  );
  return result.place;
}

/// Reverse-geocode a map coordinate into a [RidePlace] label.
Future<RidePlace> reverseGeocodeRidePlace(LatLng target) async {
  String label =
      '${target.latitude.toStringAsFixed(5)}, ${target.longitude.toStringAsFixed(5)}';
  if (kIsWeb) {
    // `geocoding` has no web implementation — use the Cloud Function proxy
    // instead (Google's Geocoding REST API blocks direct browser calls).
    final String? webLabel = await reverseGeocodeViaFunction(
      target.latitude,
      target.longitude,
    );
    if (webLabel != null) {
      label = webLabel;
    }
    return RidePlace(lat: target.latitude, lng: target.longitude, label: label);
  }
  try {
    // No timeout on this call can hang forever on a device with a degraded
    // or untrusted Play Services setup (the on-device Geocoder backend never
    // calls back) — without a bound here, "Confirm pickup/drop-off" gets
    // stuck disabled indefinitely with no way for the user to proceed.
    final List<Placemark> marks = await placemarkFromCoordinates(
      target.latitude,
      target.longitude,
    ).timeout(const Duration(seconds: 8));
    final String composed = formatBestPlacemarkLabel(marks);
    if (composed.isNotEmpty) {
      label = composed;
    }
  } catch (_) {}
  return RidePlace(lat: target.latitude, lng: target.longitude, label: label);
}

Future<RidePlace?> _promptAddressFallback(BuildContext context) async {
  final TextEditingController controller = TextEditingController();
  final String? label = await showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Enter address'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Address or place name',
          ),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Use'),
          ),
        ],
      );
    },
  );
  if (label == null || label.isEmpty) {
    return null;
  }
  return RidePlace(
    lat: kRidesDefaultCenter.latitude,
    lng: kRidesDefaultCenter.longitude,
    label: label,
  );
}
