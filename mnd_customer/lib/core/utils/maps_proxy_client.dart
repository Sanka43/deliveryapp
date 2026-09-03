import 'package:cloud_functions/cloud_functions.dart';

/// One forward-geocode search hit from the `geocodePlace` Cloud Function.
class GeoSearchHit {
  const GeoSearchHit({
    required this.label,
    required this.lat,
    required this.lng,
  });

  final String label;
  final double lat;
  final double lng;
}

FirebaseFunctions get _functions =>
    FirebaseFunctions.instanceFor(region: 'asia-south1');

/// Web-only geocoding path: `package:geocoding` has no web implementation,
/// and Google's Geocoding REST API doesn't send CORS headers for direct
/// browser calls, so this goes through our own Cloud Function instead.
/// Mobile keeps using the native `geocoding` plugin directly (works fine,
/// no CORS in a native HTTP client) — this is only wired in on web.
Future<List<GeoSearchHit>> geocodeSearchViaFunction(String query) async {
  try {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('geocodePlace')
        .call(<String, dynamic>{'query': query});
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(result.data as Map);
    final List<dynamic> raw =
        List<dynamic>.from(data['results'] as List? ?? <dynamic>[]);
    return raw
        .map((dynamic e) {
          final Map<String, dynamic> m = Map<String, dynamic>.from(e as Map);
          return GeoSearchHit(
            label: (m['label'] as String?)?.trim() ?? '',
            lat: (m['lat'] as num?)?.toDouble() ?? 0,
            lng: (m['lng'] as num?)?.toDouble() ?? 0,
          );
        })
        .where((GeoSearchHit h) => h.label.isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return const <GeoSearchHit>[];
  }
}

/// Web-only reverse-geocode: coordinates → best address label, via the same
/// `geocodePlace` Cloud Function. Returns null (never throws) on failure so
/// callers can fall back to a coordinate string.
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
    final Map<String, dynamic> first =
        Map<String, dynamic>.from(raw.first as Map);
    final String label = (first['label'] as String?)?.trim() ?? '';
    return label.isEmpty ? null : label;
  } catch (_) {
    return null;
  }
}
