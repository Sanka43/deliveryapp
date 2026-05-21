import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';

/// Admin-managed broad category (Food, Grocery). Used on vendor registration.
final class ShopCategoryOption {
  const ShopCategoryOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Active shop categories from Firestore (`shop_categories`), ordered.
final StreamProvider<List<ShopCategoryOption>> shopRegistrationCategoriesProvider =
    StreamProvider<List<ShopCategoryOption>>((Ref ref) {
  final FirebaseFirestore fs = ref.watch(firestoreProvider);
  return fs
      .collection(FirebaseCollections.shopCategories)
      .orderBy('order')
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) {
    final List<ShopCategoryOption> out = <ShopCategoryOption>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      final Map<String, dynamic> m = doc.data();
      final dynamic act = m['active'];
      if (act is bool && act == false) {
        continue;
      }
      final String? label = (m['label'] as String?)?.trim();
      if (label != null && label.isNotEmpty) {
        out.add(ShopCategoryOption(id: doc.id, label: label));
      }
    }
    return out;
  });
});

/// Shop type labels under a Firestore category (`shop_types.categoryId`).
final StreamProviderFamily<List<String>, String> shopRegistrationShopTypeLabelsProvider =
    StreamProvider.family<List<String>, String>((Ref ref, String categoryId) {
  if (categoryId.isEmpty || categoryId.startsWith('__fb_')) {
    return Stream<List<String>>.value(const <String>[]);
  }
  final FirebaseFirestore fs = ref.watch(firestoreProvider);
  return fs
      .collection(FirebaseCollections.shopTypes)
      .where('categoryId', isEqualTo: categoryId)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snap) {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = snap.docs.toList();
    docs.sort((a, b) {
      final num ao = (a.data()['order'] is num) ? (a.data()['order'] as num) : 0;
      final num bo = (b.data()['order'] is num) ? (b.data()['order'] as num) : 0;
      return ao.compareTo(bo);
    });

    final List<String> out = <String>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> m = doc.data();
      final dynamic act = m['active'];
      if (act is bool && act == false) {
        continue;
      }
      final String? label = (m['label'] as String?)?.trim();
      if (label != null && label.isNotEmpty) {
        out.add(label);
      }
    }
    return out;
  });
});
