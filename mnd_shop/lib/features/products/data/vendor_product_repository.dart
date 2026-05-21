import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';

final Provider<VendorProductRepository> vendorProductRepositoryProvider =
    Provider<VendorProductRepository>((Ref ref) {
  return VendorProductRepository(
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(firebaseStorageProvider),
  );
});

class VendorProductRepository {
  VendorProductRepository({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _firestore = firestore,
        _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection(FirebaseCollections.products);

  Stream<List<VendorProduct>> watchByStore(String storeId) {
    return _products
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) {
            final List<VendorProduct> list = snap.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                      VendorProduct.fromDoc(d),
                )
                .toList(growable: false);
            list.sort(
              (VendorProduct a, VendorProduct b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
            return list;
          },
        );
  }

  Future<String> fetchVendorDisplayName(String storeId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection(FirebaseCollections.vendors).doc(storeId).get();
    final Map<String, dynamic>? data = doc.data();
    if (data == null) {
      return 'Store';
    }
    final String? name = (data['name'] as String?)?.trim();
    return name != null && name.isNotEmpty ? name : 'Store';
  }

  String buildLookupKey(String name, String documentId) {
    final String slug = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final String safe = slug.isEmpty ? 'item' : slug;
    return '${safe}_$documentId';
  }

  /// New Firestore document id (no write) — use before Storage upload so paths match.
  String allocateProductId() => _products.doc().id;

  Future<void> createProduct({
    required String productId,
    required String storeId,
    required String storeName,
    required String name,
    required String description,
    required int priceLkr,
    required List<ProductSizeOption> sizeOptions,
    required String imageUrl,
    required bool active,
    required int stockQty,
    required String etaLabel,
  }) async {
    final DocumentReference<Map<String, dynamic>> doc = _products.doc(productId);
    final String lookupKey = buildLookupKey(name, doc.id);
    await doc.set(
      VendorProduct(
        id: doc.id,
        storeId: storeId,
        storeName: storeName,
        name: name,
        description: description,
        priceLkr: priceLkr,
        imageUrl: imageUrl,
        lookupKey: lookupKey,
        active: active,
        stockQty: stockQty.clamp(0, 9999999),
        etaLabel: etaLabel.trim(),
        sizeOptions: sizeOptions,
      ).toFirestore(storeName: storeName, lookupKey: lookupKey),
    );
  }

  Future<void> updateProduct({
    required VendorProduct existing,
    required String storeName,
    required String name,
    required String description,
    required int priceLkr,
    required List<ProductSizeOption> sizeOptions,
    required String imageUrl,
    required bool active,
    required int stockQty,
    required String etaLabel,
  }) async {
    final String lookupKey = buildLookupKey(name, existing.id);
    await _products.doc(existing.id).update(
          VendorProduct(
            id: existing.id,
            storeId: existing.storeId,
            storeName: storeName,
            name: name,
            description: description,
            priceLkr: priceLkr,
            imageUrl: imageUrl,
            lookupKey: lookupKey,
            active: active,
            stockQty: stockQty.clamp(0, 9999999),
            etaLabel: etaLabel.trim(),
            sizeOptions: sizeOptions,
          ).toFirestore(storeName: storeName, lookupKey: lookupKey),
        );
  }

  /// Sets on-hand quantity (clamped ≥ 0).
  Future<void> setProductStock({
    required String productId,
    required int quantity,
  }) async {
    final int q = quantity.clamp(0, 9999999);
    await _products.doc(productId).update(<String, dynamic>{'stockQty': q});
  }

  /// Toggle catalogue visibility (`active` flag).
  Future<void> setProductActive({
    required String productId,
    required bool active,
  }) async {
    await _products.doc(productId).update(<String, dynamic>{'active': active});
  }

  /// Adds [delta] to current stock in a transaction (won’t go below 0).
  Future<void> adjustProductStock({
    required String productId,
    required int delta,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _products.doc(productId);
    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      final Map<String, dynamic>? data = snap.data();
      final int current = (data?['stockQty'] as num?)?.round() ?? 0;
      final int next = (current + delta).clamp(0, 9999999);
      tx.update(ref, <String, dynamic>{'stockQty': next});
    });
  }

  Future<void> deleteProduct(VendorProduct product) async {
    await deleteStoredProductImage(product.imageUrl);
    await _products.doc(product.id).delete();
  }

  Future<void> deleteStoredProductImage(String imageUrl) async {
    await _tryDeleteStorageObject(imageUrl);
  }

  Future<void> _tryDeleteStorageObject(String imageUrl) async {
    if (imageUrl.isEmpty) {
      return;
    }
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return;
      }
      // Non-Firebase URL or other failures — ignore best-effort delete.
    } on Object {
      // Malformed URL / refFromURL — ignore.
    }
  }
}
