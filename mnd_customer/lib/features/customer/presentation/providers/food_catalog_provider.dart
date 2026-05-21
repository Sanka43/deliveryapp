import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';

/// Static food subcategory chips when Firestore `shop_types` is empty.
const List<String> kFoodCategoryFallbackLabels = <String>[
  'All',
  'Rice',
  'Pizza',
  'Burgers',
  'Noodles',
  'Beverages',
  'Desserts',
  'Seafood',
];

/// Product name keywords per chip label (lowercase).
const Map<String, List<String>> kFoodCategoryProductKeywords = <String, List<String>>{
  'Rice': <String>['rice', 'biryani', 'kottu', 'fried rice'],
  'Pizza': <String>['pizza'],
  'Burgers': <String>['burger', 'cheeseburger'],
  'Noodles': <String>['noodle', 'ramen', 'pasta', 'spaghetti'],
  'Beverages': <String>['drink', 'juice', 'coffee', 'tea', 'smoothie', 'milkshake'],
  'Desserts': <String>['cake', 'dessert', 'ice cream', 'brownie', 'waffle'],
  'Seafood': <String>['fish', 'prawn', 'crab', 'seafood', 'lobster'],
};

bool isGroceryStore(SearchStore store) {
  final String cat = store.category.toLowerCase();
  final String tag = store.tag.toLowerCase();
  return cat.contains('groc') ||
      tag.contains('groc') ||
      cat.contains('supermarket') ||
      tag.contains('supermarket') ||
      cat.contains('pharmacy') ||
      tag.contains('pharmacy');
}

/// Food hub: explicit food vendors, or any non-grocery shop (legacy `General` / `Store`).
bool isFoodStore(SearchStore store) {
  if (isGroceryStore(store)) {
    return false;
  }
  final String cat = store.category.toLowerCase();
  final String tag = store.tag.toLowerCase();
  if (cat.contains('food')) {
    return true;
  }
  if (tag.contains('food') ||
      tag.contains('restaurant') ||
      tag.contains('cafe') ||
      tag.contains('bakery') ||
      tag.contains('kitchen') ||
      tag.contains('dining') ||
      tag.contains('fast')) {
    return true;
  }
  return true;
}

List<SearchStore> resolveFoodStores(List<SearchStore> allStores) {
  final List<SearchStore> food = allStores.where(isFoodStore).toList(growable: false);
  if (food.isNotEmpty) {
    return food;
  }
  return allStores.where((SearchStore s) => !isGroceryStore(s)).toList(growable: false);
}

bool productMatchesFoodCategory(
  SearchProduct product,
  String? categoryLabel,
  Map<String, SearchStore> storeById,
) {
  if (categoryLabel == null || categoryLabel.isEmpty || categoryLabel == 'All') {
    return true;
  }
  final String labelLower = categoryLabel.toLowerCase();
  final SearchStore? store = storeById[product.storeId];
  if (store != null) {
    final String tagLower = store.tag.toLowerCase();
    if (tagLower == labelLower || tagLower.contains(labelLower)) {
      return true;
    }
  }
  final List<String>? keywords = kFoodCategoryProductKeywords[categoryLabel];
  final String nameLower = product.name.toLowerCase();
  if (keywords != null && keywords.isNotEmpty) {
    if (keywords.any(nameLower.contains)) {
      return true;
    }
  }
  return nameLower.contains(labelLower);
}

List<SearchProduct> rankFoodProducts(
  List<SearchProduct> products,
  List<CustomerOrderSummary> orders, {
  int maxItems = 12,
}) {
  final Set<String> preferredStores = orders
      .where((CustomerOrderSummary o) => o.statusRaw == 'delivered')
      .take(2)
      .map((CustomerOrderSummary o) => o.storeName.toLowerCase())
      .toSet();

  final List<SearchProduct> boosted = <SearchProduct>[];
  final List<SearchProduct> rest = <SearchProduct>[];

  for (final SearchProduct p in products) {
    if (preferredStores.contains(p.storeName.toLowerCase())) {
      boosted.add(p);
    } else {
      rest.add(p);
    }
  }

  final List<SearchProduct> merged = <SearchProduct>[...boosted, ...rest];
  return merged.length > maxItems ? merged.sublist(0, maxItems) : merged;
}

final StateProvider<String?> selectedFoodCategoryProvider =
    StateProvider<String?>((Ref ref) => 'All');

final Provider<List<SearchStore>> foodStoresProvider = Provider<List<SearchStore>>((Ref ref) {
  final List<SearchStore> stores = ref.watch(storesStreamProvider).maybeWhen(
        data: (List<SearchStore> items) => items,
        orElse: () => const <SearchStore>[],
      );
  return resolveFoodStores(stores);
});

final Provider<Set<String>> foodStoreIdsProvider = Provider<Set<String>>((Ref ref) {
  return ref.watch(foodStoresProvider).map((SearchStore s) => s.id).toSet();
});

final Provider<List<SearchProduct>> foodProductsProvider =
    Provider<List<SearchProduct>>((Ref ref) {
  final bool storesLoaded = ref.watch(storesStreamProvider).hasValue;
  final List<SearchProduct> products = ref.watch(productsStreamProvider).maybeWhen(
        data: (List<SearchProduct> items) => items,
        orElse: () => const <SearchProduct>[],
      );
  if (!storesLoaded || products.isEmpty) {
    return const <SearchProduct>[];
  }

  final Set<String> foodStoreIds = ref.watch(foodStoreIdsProvider);
  if (foodStoreIds.isNotEmpty) {
    final List<SearchProduct> linked = products
        .where(
          (SearchProduct p) => p.storeId.isNotEmpty && foodStoreIds.contains(p.storeId),
        )
        .toList(growable: false);
    if (linked.isNotEmpty) {
      return linked;
    }
  }

  final Map<String, String> storeNameById = <String, String>{
    for (final SearchStore s in ref.watch(foodStoresProvider)) s.id: s.name.toLowerCase(),
  };
  final List<SearchProduct> byName = products
      .where((SearchProduct p) {
        if (p.storeId.isNotEmpty && foodStoreIds.contains(p.storeId)) {
          return true;
        }
        final String name = p.storeName.toLowerCase();
        return storeNameById.values.any((String sn) => sn == name || name.contains(sn));
      })
      .toList(growable: false);
  if (byName.isNotEmpty) {
    return byName;
  }

  return products;
});

final Provider<Map<String, SearchStore>> foodStoreByIdProvider =
    Provider<Map<String, SearchStore>>((Ref ref) {
  return <String, SearchStore>{
    for (final SearchStore s in ref.watch(foodStoresProvider)) s.id: s,
  };
});

final Provider<List<SearchProduct>> filteredFoodProductsProvider =
    Provider<List<SearchProduct>>((Ref ref) {
  final String? selected = ref.watch(selectedFoodCategoryProvider);
  final List<SearchProduct> products = ref.watch(foodProductsProvider);
  final Map<String, SearchStore> storeById = ref.watch(foodStoreByIdProvider);
  return products
      .where(
        (SearchProduct p) => productMatchesFoodCategory(p, selected, storeById),
      )
      .toList(growable: false);
});

final Provider<List<SearchProduct>> popularFoodProductsProvider =
    Provider<List<SearchProduct>>((Ref ref) {
  final List<SearchProduct> filtered = ref.watch(filteredFoodProductsProvider);
  final List<CustomerOrderSummary> orders =
      ref.watch(customerOrdersStreamProvider).asData?.value ?? const <CustomerOrderSummary>[];
  return rankFoodProducts(filtered, orders);
});

List<String> _parseFoodCategoryLabels(QuerySnapshot<Map<String, dynamic>> typesSnap) {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = typesSnap.docs.toList();
  docs.sort((
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final num ao = (a.data()['order'] is num) ? (a.data()['order'] as num) : 0;
    final num bo = (b.data()['order'] is num) ? (b.data()['order'] as num) : 0;
    return ao.compareTo(bo);
  });

  final List<String> labels = <String>['All'];
  for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
    final Map<String, dynamic> m = doc.data();
    final dynamic act = m['active'];
    if (act is bool && act == false) {
      continue;
    }
    final String? label = (m['label'] as String?)?.trim();
    if (label != null && label.isNotEmpty) {
      labels.add(label);
    }
  }
  return labels.length <= 1 ? kFoodCategoryFallbackLabels : labels;
}

/// Food category chip labels from Firestore, with static fallback.
final StreamProvider<List<String>> foodCategoryLabelsProvider =
    StreamProvider<List<String>>((Ref ref) {
  final FirebaseFirestore fs = ref.watch(firestoreProvider);
  return fs
      .collection(FirebaseCollections.shopCategories)
      .orderBy('order')
      .snapshots()
      .asyncExpand((QuerySnapshot<Map<String, dynamic>> categoriesSnap) {
    String? foodCategoryId;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in categoriesSnap.docs) {
      final Map<String, dynamic> m = doc.data();
      final dynamic act = m['active'];
      if (act is bool && act == false) {
        continue;
      }
      final String? label = (m['label'] as String?)?.trim();
      if (label != null && label.toLowerCase().contains('food')) {
        foodCategoryId = doc.id;
        break;
      }
    }

    if (foodCategoryId == null || foodCategoryId.isEmpty) {
      return Stream<List<String>>.value(kFoodCategoryFallbackLabels);
    }

    return fs
        .collection(FirebaseCollections.shopTypes)
        .where('categoryId', isEqualTo: foodCategoryId)
        .snapshots()
        .map(_parseFoodCategoryLabels);
  });
});
