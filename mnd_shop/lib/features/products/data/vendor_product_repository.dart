import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/products/domain/product_option_labels.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';

/// Hard cap on catalogue size for a single food shop.
const int vendorMaxProductsPerShop = 30;

/// Higher cap for grocery shops (larger catalogs).
const int vendorMaxGroceryProductsPerShop = 100;

int vendorProductLimitForShop({required bool isGrocery}) =>
    isGrocery ? vendorMaxGroceryProductsPerShop : vendorMaxProductsPerShop;

final Provider<VendorProductRepository> vendorProductRepositoryProvider =
    Provider<VendorProductRepository>((Ref ref) {
      return VendorProductRepository(
        firestore: ref.watch(firestoreProvider),
        storage: ref.watch(firebaseStorageProvider),
      );
    });

/// Thrown when [VendorProductRepository.createProduct] would exceed the
/// per-shop catalogue cap.
class VendorProductLimitExceededException implements Exception {
  const VendorProductLimitExceededException({
    this.max = vendorMaxProductsPerShop,
  });

  final int max;

  @override
  String toString() => 'Maximum $max products per shop';
}

class VendorProductRepository {
  VendorProductRepository({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  }) : _firestore = firestore,
       _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection(FirebaseCollections.products);

  CollectionReference<Map<String, dynamic>> _stockMovements(String productId) =>
      _products.doc(productId).collection('stock_movements');

  Stream<List<VendorProduct>> watchByStore(String storeId) {
    return _products
        .where('storeId', isEqualTo: storeId)
        .orderBy('name')
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
          return snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    VendorProduct.fromDoc(d),
              )
              .toList(growable: false);
        });
  }

  Future<String> fetchVendorDisplayName(String storeId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection(FirebaseCollections.vendors)
        .doc(storeId)
        .get();
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

  Future<int> countByStore(String storeId) async {
    final String id = storeId.trim();
    if (id.isEmpty) {
      return 0;
    }
    final QuerySnapshot<Map<String, dynamic>> snap = await _products
        .where('storeId', isEqualTo: id)
        .get();
    return snap.docs.length;
  }

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
    bool manageStock = false,
    String productCategory = '',
    int? maxProducts,
  }) async {
    final int cap = maxProducts ?? vendorMaxProductsPerShop;
    final int existing = await countByStore(storeId);
    if (existing >= cap) {
      throw VendorProductLimitExceededException(max: cap);
    }
    final DocumentReference<Map<String, dynamic>> doc = _products.doc(
      productId,
    );
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
        manageStock: manageStock,
        etaLabel: etaLabel.trim(),
        productCategory: productCategory.trim(),
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
    bool manageStock = false,
    String productCategory = '',
  }) async {
    final String lookupKey = buildLookupKey(name, existing.id);
    await _products
        .doc(existing.id)
        .update(
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
            manageStock: manageStock,
            etaLabel: etaLabel.trim(),
            productCategory: productCategory.trim(),
            sizeOptions: sizeOptions,
          ).toFirestore(storeName: storeName, lookupKey: lookupKey),
        );
  }

  /// Sets on-hand quantity (clamped ≥ 0) and enables stock tracking.
  Future<void> setProductStock({
    required String productId,
    required int quantity,
    String reason = 'manual_set',
  }) async {
    final int q = quantity.clamp(0, 9999999);
    final DocumentReference<Map<String, dynamic>> ref = _products.doc(
      productId,
    );
    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      final int previous = (snap.data()?['stockQty'] as num?)?.round() ?? 0;
      tx.update(ref, <String, dynamic>{
        'stockQty': q,
        'manageStock': true,
      });
      _writeStockMovement(
        tx: tx,
        productId: productId,
        previousQty: previous,
        nextQty: q,
        reason: reason,
      );
    });
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
    String reason = 'manual_adjust',
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _products.doc(
      productId,
    );
    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      final Map<String, dynamic>? data = snap.data();
      final int current = (data?['stockQty'] as num?)?.round() ?? 0;
      final int next = (current + delta).clamp(0, 9999999);
      tx.update(ref, <String, dynamic>{
        'stockQty': next,
        'manageStock': true,
      });
      _writeStockMovement(
        tx: tx,
        productId: productId,
        previousQty: current,
        nextQty: next,
        reason: reason,
      );
    });
  }

  Future<void> setManyProductStock({
    required Map<String, int> quantitiesByProductId,
    String reason = 'bulk_set',
  }) async {
    final Map<String, int> clean = <String, int>{
      for (final MapEntry<String, int> entry in quantitiesByProductId.entries)
        if (entry.key.trim().isNotEmpty)
          entry.key.trim(): entry.value.clamp(0, 9999999),
    };
    if (clean.isEmpty) {
      return;
    }
    // Per-product transactions so concurrent sales cannot be overwritten by a
    // stale read-then-batch write.
    for (final MapEntry<String, int> entry in clean.entries) {
      await setProductStock(
        productId: entry.key,
        quantity: entry.value,
        reason: reason,
      );
    }
  }

  Future<void> autoHideOutOfStockProducts(String storeId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _products
        .where('storeId', isEqualTo: storeId)
        .where('stockQty', isEqualTo: 0)
        .get();
    if (snap.docs.isEmpty) {
      return;
    }
    final WriteBatch batch = _firestore.batch();
    var any = false;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      if (doc.data()['manageStock'] != true) {
        continue;
      }
      batch.update(doc.reference, <String, dynamic>{'active': false});
      any = true;
    }
    if (any) {
      await batch.commit();
    }
  }

  Stream<List<Map<String, dynamic>>> watchStockMovements(String productId) {
    final String id = productId.trim();
    if (id.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(
        const <Map<String, dynamic>>[],
      );
    }
    return _stockMovements(id)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                return <String, dynamic>{'id': doc.id, ...doc.data()};
              })
              .toList(growable: false),
        );
  }

  void _writeStockMovement({
    Transaction? tx,
    WriteBatch? batch,
    required String productId,
    required int previousQty,
    required int nextQty,
    required String reason,
  }) {
    final DocumentReference<Map<String, dynamic>> ref = _stockMovements(
      productId,
    ).doc();
    final Map<String, dynamic> data = <String, dynamic>{
      'previousQty': previousQty,
      'nextQty': nextQty,
      'delta': nextQty - previousQty,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (tx != null) {
      tx.set(ref, data);
      return;
    }
    batch?.set(ref, data);
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

  /// Remembers non-preset food types on `vendors/{storeId}.customFoodTypes`
  /// so they appear as chips on future add-product forms.
  Future<void> mergeCustomFoodTypes({
    required String storeId,
    required Iterable<String> types,
  }) async {
    final String id = storeId.trim();
    if (id.isEmpty) {
      return;
    }
    final List<String> cleaned = <String>[];
    final Set<String> seen = <String>{};
    for (final String raw in types) {
      final String t = raw.trim();
      if (t.isEmpty || t.length > 40) {
        continue;
      }
      // Presets are hardcoded in the form — no need to persist.
      if (kFoodTypePresets.any((String p) => p.toLowerCase() == t.toLowerCase())) {
        continue;
      }
      if (seen.add(t.toLowerCase())) {
        cleaned.add(t);
      }
    }
    if (cleaned.isEmpty) {
      return;
    }
    await _firestore.collection(FirebaseCollections.vendors).doc(id).set(
      <String, dynamic>{
        'customFoodTypes': FieldValue.arrayUnion(cleaned),
      },
      SetOptions(merge: true),
    );
  }
}
