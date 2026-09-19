import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/core/utils/maps_proxy_client.dart';
import 'package:mnd_delivery_app/core/utils/placemark_address_utils.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_pick_result.dart';

/// Resolves a human-readable delivery address for a map point, in the same
/// priority order the full map picker's "Use this location" button uses: a
/// named business/landmark right at the point, else a reverse-geocoded
/// street address, else raw coordinates. Never throws.
Future<DeliveryMapPickResult> resolveDeliveryAddressForPoint(
  LatLng point,
) async {
  // A named business/landmark right at the pin (e.g. "Pizza Hut - Badulla")
  // reads far better than a generic street address, and is the only way to
  // avoid a bare Plus Code in areas with no proper address data — same
  // reasoning that shows a label on Google Maps' own pin.
  final NearestPlaceResult? nearest = await findNearestPlaceViaFunction(
    point.latitude,
    point.longitude,
  );
  if (nearest != null) {
    final List<String> parts = nearest.formattedAddress
        .split(',')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    return DeliveryMapPickResult(
      line1: nearest.name,
      line2: '',
      city: parts.length > 1 ? parts[parts.length - 2] : '',
      latitude: point.latitude,
      longitude: point.longitude,
      placeName: nearest.name,
    );
  }

  if (kIsWeb) {
    // `geocoding` has no web implementation — use the Cloud Function proxy
    // instead (Google's Geocoding REST API blocks direct browser calls).
    final String? label = await reverseGeocodeViaFunction(
      point.latitude,
      point.longitude,
    );
    if (label != null) {
      final List<String> parts = label
          .split(',')
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList();
      return DeliveryMapPickResult(
        line1: parts.isNotEmpty ? parts.first : label,
        line2: '',
        city: parts.length > 1 ? parts[parts.length - 2] : '',
        latitude: point.latitude,
        longitude: point.longitude,
      );
    }
  } else {
    try {
      final List<Placemark> marks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      return buildDeliveryAddressFromPlacemarks(marks, point);
    } catch (_) {
      // Fall through to the raw-coordinate result below.
    }
  }

  // Reverse geocoding isn't always available — fall back to coordinates
  // rather than blocking on an address the customer can clearly see on the
  // map.
  return DeliveryMapPickResult(
    line1:
        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
    line2: '',
    city: '',
    latitude: point.latitude,
    longitude: point.longitude,
  );
}
