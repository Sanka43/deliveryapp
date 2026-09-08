import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:mnd_delivery_app/core/utils/placemark_address_utils.dart';

FirebaseFunctions get _functions =>
    FirebaseFunctions.instanceFor(region: 'asia-south1');

/// Web-only reverse-geocode: coordinates → best address label, via the same
/// `geocodePlace` Cloud Function. Returns null (never throws) on failure so
/// callers can fall back to a coordinate string.
///
/// Google's reverse-geocode results for sparsely-addressed areas (rural Sri
/// Lanka) often lead with a Plus Code (e.g. `X2GR+2XF, Badulla`) rather than
/// a street address — picking the first result blindly would show that raw
/// code to the customer, so this skips any result whose label starts with
/// one in favour of the next, real address further down the list.
Future<String?> reverseGeocodeViaFunction(double lat, double lng) async {
  try {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('geocodePlace')
        .call(<String, dynamic>{'lat': lat, 'lng': lng});
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(result.data as Map);
    final List<dynamic> raw =
        List<dynamic>.from(data['results'] as List? ?? <dynamic>[]);
    if (raw.isEmpty) {
      return null;
    }
    String? fallback;
    for (final dynamic entry in raw) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(entry as Map);
      final String label = (map['label'] as String?)?.trim() ?? '';
      if (label.isEmpty) {
        continue;
      }
      fallback ??= label;
      if (!isPlusCodeToken(label.split(',').first.trim())) {
        return label;
      }
    }
    return fallback;
  } catch (_) {
    return null;
  }
}

/// A named business/landmark found right at a pinned point, via the
/// `findNearestPlace` Cloud Function (Places API Nearby Search).
class NearestPlaceResult {
  const NearestPlaceResult({
    required this.name,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String formattedAddress;
  final double lat;
  final double lng;
}

/// Looks for a named place within ~60m of [lat]/[lng] — used when confirming
/// a dropped map pin so a recognizable landmark (e.g. "Pizza Hut - Badulla")
/// is shown instead of a generic street address, the same way Google Maps'
/// own pin label would. Returns null (never throws) when nothing is close
/// enough, so callers fall back to plain reverse geocoding.
Future<NearestPlaceResult?> findNearestPlaceViaFunction(
  double lat,
  double lng,
) async {
  try {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('findNearestPlace')
        .call(<String, dynamic>{'lat': lat, 'lng': lng});
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(result.data as Map);
    final Map<String, dynamic>? place =
        data['result'] == null ? null : Map<String, dynamic>.from(data['result'] as Map);
    if (place == null) {
      return null;
    }
    final String name = (place['name'] as String?)?.trim() ?? '';
    final double placeLat = (place['lat'] as num?)?.toDouble() ?? 0;
    final double placeLng = (place['lng'] as num?)?.toDouble() ?? 0;
    if (name.isEmpty) {
      return null;
    }
    return NearestPlaceResult(
      name: name,
      formattedAddress: (place['formattedAddress'] as String?)?.trim() ?? '',
      lat: placeLat,
      lng: placeLng,
    );
  } catch (_) {
    return null;
  }
}

/// One Places Autocomplete (New) suggestion — a business/POI or address
/// match, not yet resolved to coordinates (autocomplete predictions don't
/// carry a lat/lng; call [placeDetailsViaFunction] with [placeId] for that).
class PlaceAutocompleteHit {
  const PlaceAutocompleteHit({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
}

/// A resolved place: name, combined display label, and coordinates.
class PlaceDetailsResult {
  const PlaceDetailsResult({
    required this.placeId,
    required this.name,
    required this.label,
    required this.lat,
    required this.lng,
  });

  final String placeId;
  final String name;
  final String label;
  final double lat;
  final double lng;
}

/// A fresh Places session token. Google bills a whole autocomplete-keystrokes
/// -then-details sequence as one session when the same token is reused
/// across it, instead of billing every keystroke and the details call
/// separately — generate one when a search interaction starts and pass it to
/// every [placeAutocompleteViaFunction] call in that interaction, then the
/// one [placeDetailsViaFunction] call that closes it, and discard it.
String newPlacesSessionToken() {
  final Random random = Random.secure();
  return List<int>.generate(16, (_) => random.nextInt(256))
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// Places Autocomplete (New) search, proxied through Cloud Functions on
/// every platform — no Places SDK is wired into the mobile apps, and web
/// can't call Google's Places REST API directly (no CORS headers), same
/// reasoning as [geocodeSearchViaFunction]. Returns an empty list (never
/// throws) on failure so callers can fall back to plain geocoding.
Future<List<PlaceAutocompleteHit>> placeAutocompleteViaFunction(
  String query,
  String sessionToken, {
  double? lat,
  double? lng,
}) async {
  try {
    final HttpsCallableResult<dynamic> result =
        await _functions.httpsCallable('placeAutocomplete').call(
      <String, dynamic>{
        'query': query,
        'sessionToken': sessionToken,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(result.data as Map);
    final List<dynamic> raw =
        List<dynamic>.from(data['results'] as List? ?? <dynamic>[]);
    return raw
        .map((dynamic e) {
          final Map<String, dynamic> m = Map<String, dynamic>.from(e as Map);
          return PlaceAutocompleteHit(
            placeId: (m['placeId'] as String?)?.trim() ?? '',
            primaryText: (m['primaryText'] as String?)?.trim() ?? '',
            secondaryText: (m['secondaryText'] as String?)?.trim() ?? '',
          );
        })
        .where(
          (PlaceAutocompleteHit h) =>
              h.placeId.isNotEmpty && h.primaryText.isNotEmpty,
        )
        .toList(growable: false);
  } catch (_) {
    return const <PlaceAutocompleteHit>[];
  }
}

/// Resolves a Places Autocomplete suggestion's [placeId] into a name, label
/// and coordinates, closing out the billing session [sessionToken] started.
/// Returns null (never throws) on failure.
Future<PlaceDetailsResult?> placeDetailsViaFunction(
  String placeId,
  String sessionToken,
) async {
  try {
    final HttpsCallableResult<dynamic> result =
        await _functions.httpsCallable('placeDetails').call(
      <String, dynamic>{'placeId': placeId, 'sessionToken': sessionToken},
    );
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(result.data as Map);
    final double lat = (data['lat'] as num?)?.toDouble() ?? 0;
    final double lng = (data['lng'] as num?)?.toDouble() ?? 0;
    final String label = (data['label'] as String?)?.trim() ?? '';
    if (label.isEmpty || (lat == 0 && lng == 0)) {
      return null;
    }
    return PlaceDetailsResult(
      placeId: (data['placeId'] as String?)?.trim() ?? placeId,
      name: (data['name'] as String?)?.trim() ?? '',
      label: label,
      lat: lat,
      lng: lng,
    );
  } catch (_) {
    return null;
  }
}
