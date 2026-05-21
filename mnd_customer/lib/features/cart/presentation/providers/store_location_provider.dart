import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';

/// Pickup location for a vendor / store document.
class StoreLocation {
  const StoreLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

double? _readDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

StoreLocation? _parseVendorLocation(Map<String, dynamic>? data) {
  if (data == null) {
    return null;
  }
  final dynamic locationField = data['location'];
  if (locationField is GeoPoint) {
    return StoreLocation(
      latitude: locationField.latitude,
      longitude: locationField.longitude,
    );
  }
  final double? lat = _readDouble(data['latitude']);
  final double? lng = _readDouble(data['longitude']);
  if (lat != null && lng != null) {
    return StoreLocation(latitude: lat, longitude: lng);
  }
  return null;
}

/// Fetches optional `location` ([GeoPoint]) or `latitude` / `longitude` from
/// [FirebaseCollections.vendors] / `{storeId}`.
final storeLocationByStoreIdProvider =
    FutureProvider.autoDispose.family<StoreLocation?, String>(
  (Ref ref, String storeId) async {
    if (storeId.isEmpty) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap = await ref
        .read(firestoreProvider)
        .collection(FirebaseCollections.vendors)
        .doc(storeId)
        .get();
    if (!snap.exists) {
      return null;
    }
    return _parseVendorLocation(snap.data());
  },
);
