import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_pick_result.dart';

/// Google Open Location Code / Plus Code token (e.g. `X3R4+2MG`).
final RegExp _kPlusCodeToken = RegExp(
  r'^[A-Z0-9]{2,8}\+[A-Z0-9]{2,3}$',
  caseSensitive: false,
);

bool isPlusCodeToken(String value) =>
    _kPlusCodeToken.hasMatch(value.trim());

/// Drops Plus Codes so labels prefer real street / area names.
String cleanAddressPart(String? raw) {
  if (raw == null) {
    return '';
  }
  String value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  if (isPlusCodeToken(value)) {
    return '';
  }
  // "X3R4+2MG Badulla Road" → "Badulla Road"
  final List<String> tokens = value.split(RegExp(r'\s+'));
  if (tokens.isNotEmpty && isPlusCodeToken(tokens.first)) {
    value = tokens.skip(1).join(' ').trim();
  }
  // "X3R4+2MG, Badulla" → "Badulla"
  final List<String> commaParts = value
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty && !isPlusCodeToken(s))
      .toList();
  if (commaParts.isEmpty) {
    return '';
  }
  return commaParts.join(', ');
}

/// Human-readable label from a [Placemark] (never a bare Plus Code).
String formatPlacemarkLabel(Placemark p) {
  final String street = cleanAddressPart(p.street);
  final String thoroughfare = cleanAddressPart(p.thoroughfare);
  final String name = cleanAddressPart(p.name);
  final String subThoroughfare = cleanAddressPart(p.subThoroughfare);
  final String subLocality = cleanAddressPart(p.subLocality);
  final String locality = cleanAddressPart(p.locality);
  final String subAdmin = cleanAddressPart(p.subAdministrativeArea);
  final String admin = cleanAddressPart(p.administrativeArea);

  String primary = '';
  if (street.isNotEmpty &&
      street.toLowerCase() != locality.toLowerCase() &&
      street.toLowerCase() != admin.toLowerCase()) {
    primary = street;
  } else if (thoroughfare.isNotEmpty) {
    primary = <String>[
      if (subThoroughfare.isNotEmpty) subThoroughfare,
      thoroughfare,
    ].join(' ');
  } else if (name.isNotEmpty &&
      name.toLowerCase() != locality.toLowerCase() &&
      name.toLowerCase() != admin.toLowerCase() &&
      name.toLowerCase() != subLocality.toLowerCase()) {
    primary = name;
  }

  final List<String> parts = <String>[];
  void addUnique(String value) {
    final String v = value.trim();
    if (v.isEmpty) {
      return;
    }
    for (final String existing in parts) {
      if (existing.toLowerCase() == v.toLowerCase()) {
        return;
      }
    }
    parts.add(v);
  }

  addUnique(primary);
  addUnique(subLocality);
  addUnique(locality);
  if (parts.length < 2) {
    addUnique(subAdmin);
  }
  if (parts.length < 2) {
    addUnique(admin);
  }

  return parts.join(', ');
}

String formatBestPlacemarkLabel(List<Placemark> marks) {
  for (final Placemark p in marks) {
    final String label = formatPlacemarkLabel(p);
    if (label.isNotEmpty && !isPlusCodeToken(label.split(',').first)) {
      return label;
    }
  }
  return '';
}

String _deliveryLine1FromPlacemark(Placemark p) {
  final String street = cleanAddressPart(p.street);
  final String thoroughfare = cleanAddressPart(p.thoroughfare);
  final String name = cleanAddressPart(p.name);
  final String subThoroughfare = cleanAddressPart(p.subThoroughfare);
  final String subLocality = cleanAddressPart(p.subLocality);
  final String locality = cleanAddressPart(p.locality);
  final String subAdmin = cleanAddressPart(p.subAdministrativeArea);
  final String admin = cleanAddressPart(p.administrativeArea);

  if (street.isNotEmpty &&
      street.toLowerCase() != locality.toLowerCase() &&
      street.toLowerCase() != admin.toLowerCase()) {
    return street;
  }
  if (thoroughfare.isNotEmpty) {
    return <String>[
      if (subThoroughfare.isNotEmpty) subThoroughfare,
      thoroughfare,
    ].join(' ');
  }
  if (name.isNotEmpty &&
      name.toLowerCase() != locality.toLowerCase() &&
      name.toLowerCase() != admin.toLowerCase() &&
      name.toLowerCase() != subLocality.toLowerCase()) {
    return name;
  }
  if (subLocality.isNotEmpty) {
    return subLocality;
  }
  if (locality.isNotEmpty) {
    return locality;
  }
  if (subAdmin.isNotEmpty) {
    return subAdmin;
  }
  return admin;
}

String _deliveryCityFromPlacemark(Placemark p) {
  final String locality = cleanAddressPart(p.locality);
  if (locality.isNotEmpty) {
    return locality;
  }
  final String subAdmin = cleanAddressPart(p.subAdministrativeArea);
  if (subAdmin.isNotEmpty) {
    return subAdmin;
  }
  final String admin = cleanAddressPart(p.administrativeArea);
  if (admin.isNotEmpty) {
    return admin;
  }
  return '';
}

/// Builds checkout/manage address fields from reverse-geocode placemarks.
/// Never uses a bare Plus Code for [DeliveryMapPickResult.line1].
DeliveryMapPickResult buildDeliveryAddressFromPlacemarks(
  List<Placemark> marks,
  LatLng coordinates,
) {
  final String fallbackLine1 =
      '${coordinates.latitude.toStringAsFixed(5)}, ${coordinates.longitude.toStringAsFixed(5)}';

  if (marks.isEmpty) {
    return DeliveryMapPickResult(
      line1: fallbackLine1,
      line2: '',
      city: 'Unknown area',
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );
  }

  for (final Placemark p in marks) {
    final String line1 = _deliveryLine1FromPlacemark(p);
    if (line1.isEmpty || isPlusCodeToken(line1.split(',').first.trim())) {
      continue;
    }

    String city = _deliveryCityFromPlacemark(p);
    if (city.isEmpty) {
      city = 'Unknown area';
    }

    // Avoid duplicating city in line1 when that is all we have.
    String resolvedLine1 = line1;
    if (resolvedLine1.toLowerCase() == city.toLowerCase()) {
      final String subLocality = cleanAddressPart(p.subLocality);
      final String thoroughfare = cleanAddressPart(p.thoroughfare);
      if (thoroughfare.isNotEmpty &&
          thoroughfare.toLowerCase() != city.toLowerCase()) {
        resolvedLine1 = thoroughfare;
      } else if (subLocality.isNotEmpty &&
          subLocality.toLowerCase() != city.toLowerCase()) {
        resolvedLine1 = subLocality;
      }
    }

    final String postal = cleanAddressPart(p.postalCode);
    final String line2 = postal.isNotEmpty ? 'Postal $postal' : '';

    return DeliveryMapPickResult(
      line1: resolvedLine1,
      line2: line2,
      city: city,
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );
  }

  return DeliveryMapPickResult(
    line1: fallbackLine1,
    line2: '',
    city: 'Unknown area',
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
  );
}
