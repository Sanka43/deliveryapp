/// Grocery aisle labels aligned with customer grocery hub chips.
const List<String> kGroceryAisleLabels = <String>[
  'Fresh Produce',
  'Dairy',
  'Bakery',
  'Beverages',
  'Snacks',
  'Household',
  'Personal Care',
  'Other',
];

/// Pack / weight option presets stored as `sizeOptions[].name`.
const List<String> kGroceryPackLabels = <String>[
  '250g',
  '500g',
  '1kg',
  '1L',
  'Pack of 6',
  'Pack of 12',
];

/// Shorter ready/pick ETAs for grocery products.
const List<String> kGroceryEtaPresets = <String>[
  'Ready now',
  '15-30 min',
  '30-60 min',
  'Same day',
];

String _vendorFieldText(dynamic raw) {
  if (raw == null) {
    return '';
  }
  if (raw is String) {
    return raw.trim();
  }
  return raw.toString().trim();
}

bool _textLooksGrocery(String raw) {
  final String t = raw.toLowerCase().trim();
  if (t.isEmpty) {
    return false;
  }
  // `groc` covers Grocery/grocery; `grosery`/`grocary` catch common misspellings
  // that would otherwise save catalogKind as food at registration.
  return t.contains('groc') ||
      t.contains('grosery') ||
      t.contains('grocary') ||
      t.contains('supermarket') ||
      t.contains('hypermarket') ||
      t.contains('pharmacy') ||
      t.contains('convenience') ||
      t.contains('mini mart') ||
      t.contains('minimart') ||
      t.contains('mini-mart') ||
      t == 'mart' ||
      t.endsWith(' mart') ||
      t == 'fresh produce' ||
      t.contains('fresh produce') ||
      (t.contains('dairy') && t.contains('store'));
}

/// Canonical category label written to `vendors.category`.
/// Fixes common admin typos (e.g. Grosery → Grocery) so catalogKind + customer
/// hub detection stay aligned.
String normalizeVendorCategoryLabel(String categoryLabel) {
  final String raw = categoryLabel.trim();
  if (raw.isEmpty) {
    return raw;
  }
  final String lower = raw.toLowerCase();
  if (lower == 'grosery' ||
      lower == 'grocary' ||
      lower == 'grocries' ||
      lower == 'grosaries' ||
      lower.contains('grosery') ||
      lower.contains('grocary')) {
    return 'Grocery';
  }
  return raw;
}

/// Same spirit as customer `isGroceryStore`, plus Mini mart / convenience tags.
bool isGroceryVendorCategoryTag({
  String? category,
  String? tag,
  String? name,
}) {
  return _textLooksGrocery(category ?? '') ||
      _textLooksGrocery(tag ?? '') ||
      _textLooksGrocery(name ?? '');
}

/// True when the vendor Firestore doc should use grocery catalog UX.
///
/// Order of signals:
/// 1. Explicit `catalogKind: grocery` → grocery
/// 2. Category / tag / name heuristics (customer-aligned) → grocery
/// 3. Explicit `catalogKind: food` with no grocery signals → food
///
/// Important: a stale or category-only `catalogKind: food` must NOT hide a
/// grocery tag like "Mini mart" / "supermarket".
bool isGroceryVendorDoc(Map<String, dynamic>? map) {
  if (map == null) {
    return false;
  }
  final String kind = _vendorFieldText(map['catalogKind']).toLowerCase();
  if (kind == 'grocery' || kind == 'groc') {
    return true;
  }
  final String category = _vendorFieldText(map['category']);
  final String tag = _vendorFieldText(map['tag']);
  final String name = _vendorFieldText(map['name']).isNotEmpty
      ? _vendorFieldText(map['name'])
      : _vendorFieldText(map['displayName']);
  if (isGroceryVendorCategoryTag(category: category, tag: tag, name: name)) {
    return true;
  }
  return false;
}

/// Persistable kind from registration / settings fields.
///
/// [categoryIsGrocery] is the admin-set flag on the selected
/// `shop_categories` doc, when available — preferred over parsing
/// [categoryLabel] text so an admin renaming a category (e.g. "Grocery" to
/// something with none of the recognized keywords) can't silently
/// misclassify a new vendor registered after the rename. Falls back to the
/// text heuristic when null (legacy category docs, or tag/name signals).
String vendorCatalogKindFromFields({
  required String categoryLabel,
  String tag = '',
  String name = '',
  bool? categoryIsGrocery,
}) {
  if (categoryIsGrocery != null) {
    return categoryIsGrocery ? 'grocery' : 'food';
  }
  final String category = normalizeVendorCategoryLabel(categoryLabel);
  return isGroceryVendorCategoryTag(
        category: category,
        tag: tag,
        name: name,
      )
      ? 'grocery'
      : 'food';
}

/// Persistable kind derived from category label (legacy callers).
String vendorCatalogKindFromCategory(String categoryLabel) {
  return vendorCatalogKindFromFields(categoryLabel: categoryLabel);
}
