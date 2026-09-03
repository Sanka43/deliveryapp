import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/food_catalog_provider.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';

/// Static grocery aisle chips when Firestore `grocery_aisles` is empty.
const List<String> kGroceryCategoryFallbackLabels = <String>[
  'All',
  'Fresh Produce',
  'Dairy',
  'Bakery',
  'Beverages',
  'Snacks',
  'Household',
  'Personal Care',
];

/// Product name keywords per chip label (lowercase).
const Map<String, List<String>> kGroceryCategoryProductKeywords =
    <String, List<String>>{
  'Fresh Produce': <String>['fruit', 'veg', 'vegetable', 'salad', 'leaf', 'onion', 'tomato'],
  'Dairy': <String>['milk', 'cheese', 'yogurt', 'butter', 'curd', 'cream'],
  'Bakery': <String>['bread', 'bun', 'pastry', 'cake', 'toast'],
  'Beverages': <String>['drink', 'juice', 'water', 'soda', 'tea', 'coffee'],
  'Snacks': <String>['chip', 'biscuit', 'snack', 'cracker', 'nuts'],
  'Household': <String>['soap', 'detergent', 'cleaner', 'tissue', 'foil'],
  'Personal Care': <String>['shampoo', 'toothpaste', 'lotion', 'sanitizer'],
};

List<SearchStore> resolveGroceryStores(List<SearchStore> allStores) {
  return allStores.where(isGroceryStore).toList(growable: false);
}

/// True on an exact match, or a substring match where the shorter side is
/// long enough to be a real fragment rather than a coincidental short
/// substring (e.g. a 3-letter aisle like "Ice" shouldn't incidentally match
/// an unrelated chip like "Ice Cream" just because one contains the other).
bool _looseLabelMatch(String a, String b) {
  if (a == b) {
    return true;
  }
  final String shorter = a.length <= b.length ? a : b;
  final String longer = a.length <= b.length ? b : a;
  if (shorter.length < 4) {
    return false;
  }
  return longer.contains(shorter);
}

bool productMatchesGroceryCategory(
  SearchProduct product,
  String? categoryLabel,
  Map<String, SearchStore> storeById,
) {
  if (categoryLabel == null || categoryLabel.isEmpty || categoryLabel == 'All') {
    return true;
  }
  final String labelLower = categoryLabel.toLowerCase();
  final String aisle = product.productCategory.trim().toLowerCase();
  if (aisle.isNotEmpty && _looseLabelMatch(aisle, labelLower)) {
    return true;
  }
  final SearchStore? store = storeById[product.storeId];
  if (store != null) {
    final String tagLower = store.tag.toLowerCase();
    if (tagLower == labelLower || tagLower.contains(labelLower)) {
      return true;
    }
  }
  final List<String>? keywords = kGroceryCategoryProductKeywords[categoryLabel];
  final String nameLower = product.name.toLowerCase();
  if (keywords != null && keywords.isNotEmpty) {
    if (keywords.any(nameLower.contains)) {
      return true;
    }
  }
  return nameLower.contains(labelLower);
}

bool storeMatchesGroceryCategory(SearchStore store, String? categoryLabel) {
  if (categoryLabel == null || categoryLabel.isEmpty || categoryLabel == 'All') {
    return true;
  }
  final String labelLower = categoryLabel.toLowerCase();
  final String tagLower = store.tag.toLowerCase();
  final String catLower = store.category.toLowerCase();
  final String nameLower = store.name.toLowerCase();
  return tagLower == labelLower ||
      tagLower.contains(labelLower) ||
      catLower.contains(labelLower) ||
      nameLower.contains(labelLower);
}

final StateProvider<String?> selectedGroceryCategoryProvider =
    StateProvider<String?>((Ref ref) => 'All');

final Provider<List<SearchStore>> groceryStoresProvider =
    Provider<List<SearchStore>>((Ref ref) {
  final List<SearchStore> stores = ref.watch(browseStoresStreamProvider).maybeWhen(
        data: (List<SearchStore> items) => items,
        orElse: () => const <SearchStore>[],
      );
  return resolveGroceryStores(stores);
});

/// Grocery shops filtered by selected category chip (All = full grocery list).
final Provider<List<SearchStore>> filteredGroceryStoresProvider =
    Provider<List<SearchStore>>((Ref ref) {
  final String? selected = ref.watch(selectedGroceryCategoryProvider);
  final List<SearchStore> stores = ref.watch(groceryStoresProvider);
  return stores
      .where((SearchStore s) => storeMatchesGroceryCategory(s, selected))
      .toList(growable: false);
});

final Provider<Set<String>> groceryStoreIdsProvider = Provider<Set<String>>((Ref ref) {
  return ref.watch(groceryStoresProvider).map((SearchStore s) => s.id).toSet();
});

final Provider<List<SearchProduct>> groceryProductsProvider =
    Provider<List<SearchProduct>>((Ref ref) {
  final bool storesLoaded = ref.watch(browseStoresStreamProvider).hasValue;
  final List<SearchProduct> products = ref.watch(browseProductsStreamProvider).maybeWhen(
        data: (List<SearchProduct> items) => items,
        orElse: () => const <SearchProduct>[],
      );
  if (!storesLoaded || products.isEmpty) {
    return const <SearchProduct>[];
  }

  final Set<String> groceryStoreIds = ref.watch(groceryStoreIdsProvider);
  if (groceryStoreIds.isEmpty) {
    return const <SearchProduct>[];
  }

  final List<SearchProduct> linked = products
      .where(
        (SearchProduct p) =>
            p.storeId.isNotEmpty && groceryStoreIds.contains(p.storeId),
      )
      .toList(growable: false);
  if (linked.isNotEmpty) {
    return linked;
  }

  final Map<String, String> storeNameById = <String, String>{
    for (final SearchStore s in ref.watch(groceryStoresProvider))
      s.id: s.name.toLowerCase(),
  };
  return products
      .where((SearchProduct p) {
        if (p.storeId.isNotEmpty && groceryStoreIds.contains(p.storeId)) {
          return true;
        }
        final String name = p.storeName.toLowerCase();
        return storeNameById.values
            .any((String sn) => sn == name || name.contains(sn));
      })
      .toList(growable: false);
});

final Provider<Map<String, SearchStore>> groceryStoreByIdProvider =
    Provider<Map<String, SearchStore>>((Ref ref) {
  return <String, SearchStore>{
    for (final SearchStore s in ref.watch(groceryStoresProvider)) s.id: s,
  };
});

final Provider<List<SearchProduct>> filteredGroceryProductsProvider =
    Provider<List<SearchProduct>>((Ref ref) {
  final String? selected = ref.watch(selectedGroceryCategoryProvider);
  final List<SearchProduct> products = ref.watch(groceryProductsProvider);
  final Map<String, SearchStore> storeById = ref.watch(groceryStoreByIdProvider);
  return products
      .where(
        (SearchProduct p) => productMatchesGroceryCategory(p, selected, storeById),
      )
      .toList(growable: false);
});

final Provider<List<SearchProduct>> popularGroceryProductsProvider =
    Provider<List<SearchProduct>>((Ref ref) {
  final List<SearchProduct> filtered = ref.watch(filteredGroceryProductsProvider);
  final List<CustomerOrderSummary> orders =
      ref.watch(customerOrdersStreamProvider).asData?.value ??
          const <CustomerOrderSummary>[];
  return rankFoodProducts(filtered, orders);
});

List<String> _parseGroceryAisleChipLabels(
  QuerySnapshot<Map<String, dynamic>> snap,
) {
  final List<String> labels = <String>['All'];
  for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
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
  return labels.length <= 1 ? kGroceryCategoryFallbackLabels : labels;
}

/// Grocery aisle chip labels from `grocery_aisles`, with static fallback.
final StreamProvider<List<String>> groceryCategoryLabelsProvider =
    StreamProvider<List<String>>((Ref ref) {
  final FirebaseFirestore fs = ref.watch(firestoreProvider);
  return fs
      .collection(FirebaseCollections.groceryAisles)
      .orderBy('order')
      .snapshots()
      .map(_parseGroceryAisleChipLabels);
});
