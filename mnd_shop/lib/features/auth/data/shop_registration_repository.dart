import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/auth/data/shop_gallery_storage.dart';
import 'package:mnd_shop/features/auth/domain/shop_registration_payload.dart';
import 'package:mnd_shop/features/products/data/vendor_product_repository.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_store_id_provider.dart';

final Provider<ShopRegistrationRepository> shopRegistrationRepositoryProvider =
    Provider<ShopRegistrationRepository>((Ref ref) {
  return ShopRegistrationRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    products: ref.watch(vendorProductRepositoryProvider),
    gallery: ref.watch(shopGalleryStorageProvider),
    ref: ref,
  );
});

class ShopRegistrationResult {
  const ShopRegistrationResult._({this.errorMessage});

  const ShopRegistrationResult.success() : errorMessage = null;

  factory ShopRegistrationResult.failure(String message) {
    return ShopRegistrationResult._(errorMessage: message);
  }

  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

/// Registers Firebase Auth, uploads shop photos, writes `vendors/{uid}` with
/// [approvalStatus] `pending` and [active] `false` until an admin approves.
class ShopRegistrationRepository {
  ShopRegistrationRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required VendorProductRepository products,
    required ShopGalleryStorage gallery,
    required Ref ref,
  })  : _auth = auth,
        _firestore = firestore,
        _products = products,
        _gallery = gallery,
        _ref = ref;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final VendorProductRepository _products;
  final ShopGalleryStorage _gallery;
  final Ref _ref;
  static final RegExp _phonePattern = RegExp(r'^\+?[0-9][0-9\s\-]{7,31}$');

  Future<ShopRegistrationResult> registerNewShop(ShopRegistrationPayload p) async {
    final String name = p.shopDisplayName.trim();
    final String em = p.email.trim();
    if (name.isEmpty) {
      return ShopRegistrationResult.failure('Shop name is required.');
    }
    if (name.length > 120) {
      return ShopRegistrationResult.failure('Shop name is too long.');
    }
    if (em.isEmpty) {
      return ShopRegistrationResult.failure('Email is required.');
    }
    if (p.password.length < 6) {
      return ShopRegistrationResult.failure('Password must be at least 6 characters.');
    }
    final String phone = p.phone.trim();
    if (!_phonePattern.hasMatch(phone)) {
      return ShopRegistrationResult.failure('Enter a valid shop phone (8–32 digits).');
    }
    final String line = p.addressLine.trim();
    final String city = p.city.trim();
    if (line.isEmpty || city.isEmpty) {
      return ShopRegistrationResult.failure('Address and city are required.');
    }
    if (p.latitude.abs() > 90 || p.longitude.abs() > 180) {
      return ShopRegistrationResult.failure('Check latitude / longitude.');
    }
    final List<Uint8List> imgs = p.nonEmptyPhotos;
    if (imgs.isEmpty) {
      return ShopRegistrationResult.failure('Add at least one shop photo (up to four).');
    }
    if (imgs.length > 4) {
      return ShopRegistrationResult.failure('Too many photos.');
    }
    final String? wa = p.whatsapp?.trim();
    if (wa != null && wa.isNotEmpty && !_phonePattern.hasMatch(wa)) {
      return ShopRegistrationResult.failure('Enter a valid WhatsApp number.');
    }

    User? createdUser;
    String? createdStoreId;
    bool vendorDocWritten = false;
    try {
      final UserCredential cred =
          await _auth.createUserWithEmailAndPassword(email: em, password: p.password);
      final User? user = cred.user;
      if (user == null) {
        return ShopRegistrationResult.failure('Account created but user is null.');
      }
      createdUser = user;
      final String uid = user.uid;
      final String storeId = uid;
      createdStoreId = storeId;

      final List<String> galleryUrls = <String>[];
      for (int i = 0; i < imgs.length; i++) {
        final String url = await _gallery.uploadShopPhoto(
          storeId: storeId,
          index: i,
          bytes: imgs[i],
          fileName: 'shop_$i.jpg',
        );
        galleryUrls.add(url);
      }

      await _firestore.collection(FirebaseCollections.vendors).doc(storeId).set(<String, dynamic>{
        'uid': uid,
        'role': 'vendor',
        'vendorStoreId': storeId,
        'name': name,
        'description': p.shopDescription.trim(),
        'email': em,
        'phone': phone,
        if (wa != null && wa.isNotEmpty) 'whatsapp': wa,
        'addressLine': line,
        'city': city,
        'location': GeoPoint(p.latitude, p.longitude),
        'latitude': p.latitude,
        'longitude': p.longitude,
        'category': p.categoryLabel.trim().isEmpty ? 'General' : p.categoryLabel.trim(),
        'tag': p.shopTypeLabel.trim().isEmpty ? 'Store' : p.shopTypeLabel.trim(),
        // Shop-level ETA and delivery fee are no longer maintained here.
        'openingHours': <String, dynamic>{
          'defaultOpen': p.openTime,
          'defaultClose': p.closeTime,
          'closedSunday': p.closedSunday,
          if (p.openingHoursExtraNote.trim().isNotEmpty)
            'note': p.openingHoursExtraNote.trim(),
        },
        'wageNotes': <String, dynamic>{
          'kitchen': p.wageKitchenNotes.trim(),
          'counter': p.wageCounterNotes.trim(),
          'delivery': p.wageDeliveryNotes.trim(),
        },
        'galleryImageUrls': galleryUrls,
        'imageUrl': galleryUrls.isNotEmpty ? galleryUrls.first : '',
        'rating': 0,
        'approvalStatus': 'pending',
        'active': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      vendorDocWritten = true;

      await _ref.read(vendorStoreIdProvider.notifier).setStoreId(storeId);

      await _seedDemoProducts(
        storeId: storeId,
        storeName: name,
      );

      return const ShopRegistrationResult.success();
    } on FirebaseAuthException catch (e) {
      return ShopRegistrationResult.failure(_mapAuthError(e));
    } on FirebaseException catch (e) {
      await _rollbackPartialRegistration(
        storeId: createdStoreId,
        createdUser: createdUser,
        vendorDocWritten: vendorDocWritten,
      );
      return ShopRegistrationResult.failure(_mapFirebaseError(e));
    } catch (e) {
      await _rollbackPartialRegistration(
        storeId: createdStoreId,
        createdUser: createdUser,
        vendorDocWritten: vendorDocWritten,
      );
      return ShopRegistrationResult.failure(
        'Could not complete registration now. Please try again.',
      );
    }
  }

  Future<void> _rollbackPartialRegistration({
    required String? storeId,
    required User? createdUser,
    required bool vendorDocWritten,
  }) async {
    if (storeId != null && storeId.isNotEmpty) {
      try {
        await _gallery.deleteShopPhotos(storeId: storeId);
      } catch (_) {}
    }
    if (vendorDocWritten && storeId != null && storeId.isNotEmpty) {
      try {
        await _firestore.collection(FirebaseCollections.vendors).doc(storeId).delete();
      } catch (_) {}
    }
    if (createdUser != null) {
      final User? current = _auth.currentUser;
      if (current != null && current.uid == createdUser.uid) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already used. Try logging in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Use a stronger password (at least 6 characters).';
      case 'operation-not-allowed':
        return 'Email signup is currently disabled.';
      default:
        return 'Could not create your account now. Please try again.';
    }
  }

  String _mapFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied while saving your shop.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      case 'cancelled':
        return 'Request cancelled. Please try again.';
      default:
        return 'Could not save your shop details now. Please try again.';
    }
  }

  Future<void> _seedDemoProducts({
    required String storeId,
    required String storeName,
  }) async {
    final List<_DemoLine> lines = <_DemoLine>[
      _DemoLine(name: 'Rice & curry (veg)', price: 450, desc: 'Demo starter item — edit or delete anytime.'),
      _DemoLine(name: 'Kottu roti (chicken)', price: 890, desc: 'Demo starter item.'),
      _DemoLine(name: 'Faluda', price: 380, desc: 'Demo drink.'),
    ];
    for (final _DemoLine line in lines) {
      final String pid = _products.allocateProductId();
      await _products.createProduct(
        productId: pid,
        storeId: storeId,
        storeName: storeName,
        name: line.name,
        description: line.desc,
        priceLkr: line.price,
        sizeOptions: const <ProductSizeOption>[],
        imageUrl: '',
        active: true,
        stockQty: 20,
        etaLabel: '20-30 min',
      );
    }
  }
}

class _DemoLine {
  const _DemoLine({
    required this.name,
    required this.price,
    required this.desc,
  });

  final String name;
  final int price;
  final String desc;
}
