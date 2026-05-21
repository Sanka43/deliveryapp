import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Resolved GPS label for the home header.
class CustomerLiveLocationLabel {
  const CustomerLiveLocationLabel({
    required this.line,
    this.city,
    required this.isLive,
  });

  const CustomerLiveLocationLabel.loading()
      : line = 'Getting your location…',
        city = null,
        isLive = false;

  const CustomerLiveLocationLabel.unavailable(this.line)
      : city = null,
        isLive = false;

  final String line;
  final String? city;
  final bool isLive;
}

class CustomerLiveLocationService {
  static String formatPlacemarkLine(Placemark p) {
    final String street = (p.street ?? '').trim();
    final String thoroughfare = (p.thoroughfare ?? '').trim();
    final String name = (p.name ?? '').trim();
    final String sub = (p.subThoroughfare ?? '').trim();

    String primary;
    if (street.isNotEmpty) {
      primary = street;
    } else {
      final List<String> parts = <String>[
        if (sub.isNotEmpty) sub,
        if (thoroughfare.isNotEmpty) thoroughfare,
        if (name.isNotEmpty && name != thoroughfare) name,
      ];
      primary = parts.join(', ');
    }

    final String city =
        (p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? '')
            .trim();

    if (primary.isEmpty && city.isNotEmpty) {
      return city;
    }
    if (primary.isNotEmpty && city.isNotEmpty && !primary.contains(city)) {
      return '$primary, $city';
    }
    return primary.isNotEmpty ? primary : (city.isNotEmpty ? city : 'Unknown area');
  }

  static Future<CustomerLiveLocationLabel> labelForPosition(Position position) async {
    try {
      final List<Placemark> marks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (marks.isEmpty) {
        return CustomerLiveLocationLabel(
          line:
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
          isLive: true,
        );
      }
      final Placemark p = marks.first;
      final String city =
          (p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? '')
              .trim();
      return CustomerLiveLocationLabel(
        line: formatPlacemarkLine(p),
        city: city.isNotEmpty ? city : null,
        isLive: true,
      );
    } catch (_) {
      return CustomerLiveLocationLabel(
        line:
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        isLive: true,
      );
    }
  }

  static Future<CustomerLiveLocationLabel?> resolveCurrent() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const CustomerLiveLocationLabel.unavailable(
        'Turn on location services',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const CustomerLiveLocationLabel.unavailable(
        'Allow location to see where you are',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      return const CustomerLiveLocationLabel.unavailable(
        'Location permission blocked in settings',
      );
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () async {
          final Position? last = await Geolocator.getLastKnownPosition();
          if (last != null) {
            return last;
          }
          throw TimeoutException('Location timed out');
        },
      );
      return labelForPosition(position);
    } catch (_) {
      final Position? last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return labelForPosition(last);
      }
      return const CustomerLiveLocationLabel.unavailable(
        'Could not get your location',
      );
    }
  }

  static Stream<CustomerLiveLocationLabel> watch() async* {
    yield const CustomerLiveLocationLabel.loading();

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      yield const CustomerLiveLocationLabel.unavailable(
        'Turn on location services',
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      yield const CustomerLiveLocationLabel.unavailable(
        'Allow location to see where you are',
      );
      return;
    }
    if (permission == LocationPermission.deniedForever) {
      yield const CustomerLiveLocationLabel.unavailable(
        'Location permission blocked in settings',
      );
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      yield await labelForPosition(position);
    } catch (_) {
      final Position? last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        yield await labelForPosition(last);
      }
    }

    await for (final Position position in Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 45,
      ),
    )) {
      yield await labelForPosition(position);
    }
  }
}
