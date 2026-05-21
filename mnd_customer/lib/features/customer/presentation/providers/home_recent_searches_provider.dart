import 'package:flutter_riverpod/flutter_riverpod.dart';
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
