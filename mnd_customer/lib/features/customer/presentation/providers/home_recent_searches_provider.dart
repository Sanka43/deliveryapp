import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kRecentSearchesKey = 'home_recent_searches';
const int _kMaxRecent = 5;

const List<String> kHomeTrendingSearches = <String>[
  'Rice',
  'Kottu',
  'Pharmacy',
  'Coca Cola',
];

final FutureProvider<SharedPreferences> sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((Ref ref) async {
  return SharedPreferences.getInstance();
});

final StateNotifierProvider<HomeRecentSearchesNotifier, List<String>>
    homeRecentSearchesProvider =
    StateNotifierProvider<HomeRecentSearchesNotifier, List<String>>(
  (Ref ref) => HomeRecentSearchesNotifier(ref),
);

class HomeRecentSearchesNotifier extends StateNotifier<List<String>> {
  HomeRecentSearchesNotifier(this._ref) : super(const <String>[]) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final SharedPreferences prefs = await _ref.read(sharedPreferencesProvider.future);
    final List<String> stored =
        prefs.getStringList(_kRecentSearchesKey) ?? const <String>[];
    state = stored;
  }

  Future<void> addSearch(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final List<String> next = <String>[
      trimmed,
      ...state.where((String s) => s.toLowerCase() != trimmed.toLowerCase()),
    ];
    if (next.length > _kMaxRecent) {
      state = next.sublist(0, _kMaxRecent);
    } else {
      state = next;
    }
    final SharedPreferences prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setStringList(_kRecentSearchesKey, state);
  }
}

final StateNotifierProvider<ProductFavoritesNotifier, Set<String>>
    productFavoritesProvider =
    StateNotifierProvider<ProductFavoritesNotifier, Set<String>>(
  (Ref ref) => ProductFavoritesNotifier(ref),
);

class ProductFavoritesNotifier extends StateNotifier<Set<String>> {
  ProductFavoritesNotifier(this._ref) : super(<String>{}) {
    _load();
  }

  static const String _kFavoritesKey = 'home_product_favorites';

  final Ref _ref;

  Future<void> _load() async {
    final SharedPreferences prefs = await _ref.read(sharedPreferencesProvider.future);
    final List<String>? stored = prefs.getStringList(_kFavoritesKey);
    if (stored != null) {
      state = stored.toSet();
    }
  }

  Future<void> toggle(String productKey) async {
    final Set<String> next = Set<String>.from(state);
    if (next.contains(productKey)) {
      next.remove(productKey);
    } else {
      next.add(productKey);
    }
    state = next;
    final SharedPreferences prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setStringList(_kFavoritesKey, next.toList());
  }

  bool isFavorite(String productKey) => state.contains(productKey);
}

/// Targeted favorite resolution — avoids downloading the full products catalog.
final FutureProvider<List<SearchProduct>> favoriteProductsProvider =
    FutureProvider<List<SearchProduct>>((Ref ref) async {
  final Set<String> keys = ref.watch(productFavoritesProvider);
  if (keys.isEmpty) {
    return const <SearchProduct>[];
  }

  final FirebaseFirestore firestore = ref.watch(firestoreProvider);
  final List<String> orderedKeys = keys
      .map((String k) => k.trim())
      .where((String k) => k.isNotEmpty)
      .toList(growable: false);
  final Map<String, SearchProduct> byToken = <String, SearchProduct>{};

  Future<void> ingest(QuerySnapshot<Map<String, dynamic>> snap) async {
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      final Map<String, dynamic> data = doc.data();
      if (data['active'] == false) {
        continue;
      }
      final SearchProduct product = SearchProduct.fromFirestore(doc.id, data);
      byToken[product.lookupKey] = product;
      byToken[product.name] = product;
      byToken[product.documentId] = product;
      byToken[product.documentId.toLowerCase()] = product;
    }
  }

  final List<String> lookupTokens = orderedKeys
      .map((String k) => k.toLowerCase())
      .toSet()
      .toList(growable: false);
  for (int i = 0; i < lookupTokens.length; i += 30) {
    final List<String> chunk = lookupTokens.sublist(
      i,
      i + 30 > lookupTokens.length ? lookupTokens.length : i + 30,
    );
    await ingest(
      await firestore
          .collection(FirebaseCollections.products)
          .where('lookupKey', whereIn: chunk)
          .get(),
    );
  }

  for (final String key in orderedKeys) {
    if (byToken.containsKey(key) || byToken.containsKey(key.toLowerCase())) {
      continue;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc = await firestore
        .collection(FirebaseCollections.products)
        .doc(key)
        .get();
    final Map<String, dynamic>? data = doc.data();
    if (!doc.exists || data == null || data['active'] == false) {
      continue;
    }
    final SearchProduct product = SearchProduct.fromFirestore(doc.id, data);
    byToken[key] = product;
    byToken[product.lookupKey] = product;
  }

  final List<SearchProduct> out = <SearchProduct>[];
  final Set<String> seen = <String>{};
  for (final String key in orderedKeys) {
    final SearchProduct? product =
        byToken[key] ?? byToken[key.toLowerCase()];
    if (product != null && seen.add(product.documentId)) {
      out.add(product);
    }
  }
  return out;
});
