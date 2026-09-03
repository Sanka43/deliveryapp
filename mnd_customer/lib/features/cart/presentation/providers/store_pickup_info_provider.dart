import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/store_location_provider.dart';

/// Vendor address snapshot for self-pickup checkout UI.
class StorePickupInfo {
  const StorePickupInfo({
    required this.storeId,
    required this.name,
    required this.addressLine,
    required this.city,
    required this.phone,
    this.location,
  });

  final String storeId;
  final String name;
  final String addressLine;
  final String city;
  final String phone;
  final StoreLocation? location;

  String get formattedAddress {
    final List<String> parts = <String>[
      if (addressLine.trim().isNotEmpty) addressLine.trim(),
      if (city.trim().isNotEmpty) city.trim(),
    ];
    return parts.join(', ');
  }

  bool get hasAddress => formattedAddress.isNotEmpty;
}

final storePickupInfoByStoreIdProvider =
    FutureProvider.autoDispose.family<StorePickupInfo?, String>(
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
    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
    final String name = (data['name'] as String?)?.trim() ?? 'Store';
    final String addressLine = (data['addressLine'] as String?)?.trim() ??
        (data['address'] as String?)?.trim() ??
        '';
    final String city = (data['city'] as String?)?.trim() ?? '';
    final String phone = (data['phone'] as String?)?.trim() ?? '';

    StoreLocation? location;
    final dynamic locationField = data['location'];
    if (locationField is GeoPoint) {
      location = StoreLocation(
        latitude: locationField.latitude,
        longitude: locationField.longitude,
      );
    } else {
      final dynamic lat = data['latitude'];
      final dynamic lng = data['longitude'];
      if (lat is num && lng is num) {
        location = StoreLocation(
          latitude: lat.toDouble(),
          longitude: lng.toDouble(),
        );
      }
    }

    return StorePickupInfo(
      storeId: storeId,
      name: name.isEmpty ? 'Store' : name,
      addressLine: addressLine,
      city: city,
      phone: phone,
      location: location,
    );
  },
);
