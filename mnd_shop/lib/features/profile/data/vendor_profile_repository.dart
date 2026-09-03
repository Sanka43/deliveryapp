import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/auth/data/shop_gallery_storage.dart';
import 'package:mnd_shop/features/products/domain/vendor_grocery_catalog.dart';

final Provider<VendorProfileRepository> vendorProfileRepositoryProvider =
    Provider<VendorProfileRepository>((Ref ref) {
  return VendorProfileRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    gallery: ref.watch(shopGalleryStorageProvider),
  );
});

class VendorProfileRepository {
  VendorProfileRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required ShopGalleryStorage gallery,
  })  : _firestore = firestore,
        _auth = auth,
        _gallery = gallery;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ShopGalleryStorage _gallery;

  DocumentReference<Map<String, dynamic>>? _myVendorDoc() {
    final String? uid = _auth.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      return null;
    }
    return _firestore.collection(FirebaseCollections.vendors).doc(uid);
  }

  Future<String?> updateMyShopProfile({
    required String name,
    required String description,
    required String phone,
    required String whatsapp,
    required String addressLine,
    required String city,
    required String openTime,
    required String closeTime,
    required bool closedSunday,
    required String openingNote,
  }) async {
    final User? u = _auth.currentUser;
    if (u == null) {
      return 'Sign in first.';
    }
    final String n = name.trim();
    final String d = description.trim();
    final String p = phone.trim();
    final String wa = whatsapp.trim();
    final String line = addressLine.trim();
    final String c = city.trim();
    final String ot = openTime.trim();
    final String ct = closeTime.trim();
    final String note = openingNote.trim();

    if (n.isEmpty) return 'Shop name is required.';
    if (n.length > 120) return 'Shop name is too long.';
    if (d.isEmpty) return 'Description is required.';
    if (d.length > 200) return 'Description max 200 characters.';
    if (p.length < 8 || p.length > 32) return 'Enter a valid shop phone (8–32 digits).';
    if (line.isEmpty || c.isEmpty) return 'Address and city are required.';
    if (ot.isEmpty || ct.isEmpty) return 'Opening hours are required.';
    if (note.length > 80) return 'Opening note max 80 characters.';
    if (wa.length > 32) return 'WhatsApp number is too long.';

    try {
      await _firestore.collection(FirebaseCollections.vendors).doc(u.uid).set(
        <String, dynamic>{
          'name': n,
          'description': d,
          'phone': p,
          if (wa.isNotEmpty) 'whatsapp': wa else 'whatsapp': FieldValue.delete(),
          'addressLine': line,
          'city': c,
          'openingHours': <String, dynamic>{
            'defaultOpen': ot,
            'defaultClose': ct,
            'closedSunday': closedSunday,
            if (note.isNotEmpty) 'note': note else 'note': FieldValue.delete(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return null;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not save profile.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not save profile.');
    }
  }

  Future<String?> updateGalleryUrls(List<String> galleryUrls) async {
    final DocumentReference<Map<String, dynamic>>? doc = _myVendorDoc();
    if (doc == null) {
      return 'Sign in first.';
    }
    final List<String> urls = galleryUrls
        .map((String u) => u.trim())
        .where((String u) => u.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) {
      return 'Add at least one shop photo.';
    }
    if (urls.length > 4) {
      return 'Maximum 4 photos.';
    }
    try {
      await doc.set(
        <String, dynamic>{
          'galleryImageUrls': urls,
          'imageUrl': urls.first,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return null;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not update gallery.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not update gallery.');
    }
  }

  Future<({String? error, String? url})> uploadGalleryPhoto({
    required int index,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final String? uid = _auth.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      return (error: 'Sign in first.', url: null);
    }
    if (index < 0 || index > 3) {
      return (error: 'Invalid photo slot.', url: null);
    }
    try {
      final String url = await _gallery.uploadShopPhoto(
        storeId: uid,
        index: index,
        bytes: bytes,
        fileName: fileName,
      );
      return (error: null, url: url);
    } on FirebaseException catch (e) {
      return (
        error: userFacingError(e, fallback: 'Could not upload photo.'),
        url: null,
      );
    } catch (e) {
      return (
        error: userFacingError(e, fallback: 'Could not upload photo.'),
        url: null,
      );
    }
  }

  Future<String?> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    final DocumentReference<Map<String, dynamic>>? doc = _myVendorDoc();
    if (doc == null) {
      return 'Sign in first.';
    }
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      return 'Invalid coordinates.';
    }
    try {
      await doc.set(
        <String, dynamic>{
          'location': GeoPoint(latitude, longitude),
          'latitude': latitude,
          'longitude': longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return null;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not update location.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not update location.');
    }
  }

  Future<String?> updateCategoryTag({
    required String category,
    required String tag,
  }) async {
    final DocumentReference<Map<String, dynamic>>? doc = _myVendorDoc();
    if (doc == null) {
      return 'Sign in first.';
    }
    final String c = normalizeVendorCategoryLabel(category.trim());
    final String t = tag.trim();
    if (c.isEmpty || t.isEmpty) {
      return 'Category and shop type are required.';
    }
    try {
      await doc.set(
        <String, dynamic>{
          'category': c,
          'tag': t,
          'catalogKind': vendorCatalogKindFromFields(
            categoryLabel: c,
            tag: t,
          ),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return null;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not update category.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not update category.');
    }
  }

  Future<String?> updateBusinessSettings({
    required double? minOrderLkr,
    required String kitchenNotes,
    required String counterNotes,
    required String deliveryNotes,
  }) async {
    final DocumentReference<Map<String, dynamic>>? doc = _myVendorDoc();
    if (doc == null) {
      return 'Sign in first.';
    }
    if (minOrderLkr != null && minOrderLkr < 0) {
      return 'Minimum order cannot be negative.';
    }
    final String k = kitchenNotes.trim();
    final String c = counterNotes.trim();
    final String d = deliveryNotes.trim();
    if (k.length > 200 || c.length > 200 || d.length > 200) {
      return 'Each note must be 200 characters or less.';
    }
    try {
      final Map<String, dynamic> patch = <String, dynamic>{
        'wageNotes': <String, dynamic>{
          if (k.isNotEmpty) 'kitchen': k else 'kitchen': FieldValue.delete(),
          if (c.isNotEmpty) 'counter': c else 'counter': FieldValue.delete(),
          if (d.isNotEmpty) 'delivery': d else 'delivery': FieldValue.delete(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (minOrderLkr == null || minOrderLkr <= 0) {
        patch['minOrderLkr'] = FieldValue.delete();
      } else {
        patch['minOrderLkr'] = minOrderLkr;
      }
      await doc.set(patch, SetOptions(merge: true));
      return null;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not save settings.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not save settings.');
    }
  }
}

