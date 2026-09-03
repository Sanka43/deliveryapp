import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/utils/catalog_image_url.dart';
import 'package:mnd_delivery_app/core/utils/product_price_display.dart';
import 'package:mnd_delivery_app/features/store/domain/product_availability.dart';

class SearchStore {
  const SearchStore({
    required this.id,
    required this.name,
    required this.category,
    required this.tag,
    required this.rating,
    required this.eta,
    required this.imageUrl,
    required this.deliveryFee,
    this.address = '',
    this.phone = '',
    this.isOpen = true,
    this.catalogKind = '',
  });

  final String id;
  final String name;

  /// Broad vendor group from Firestore `category` (e.g. Food, Grocery).
  final String category;

  /// Shop type from Firestore `tag` (e.g. Restaurant, Bakery).
  final String tag;
  final double rating;
  final String eta;
  final String imageUrl;
  final String deliveryFee;

  /// Street / area text for store details (optional).
  final String address;

  /// Contact phone for store details (optional).
  final String phone;

  /// Whether the shop is currently open for orders.
  final bool isOpen;

  /// Persisted catalog bucket from shop app (`grocery` / `food`).
  final String catalogKind;

  factory SearchStore.fromFirestore(
    String id,
    Map<String, dynamic> map,
  ) {
    final dynamic feeRaw = map['deliveryFee'];
    final String deliveryFee;
    if (feeRaw is String && feeRaw.trim().isNotEmpty) {
      deliveryFee = feeRaw.trim();
    } else if (feeRaw is num) {
      deliveryFee = 'LKR ${feeRaw.toStringAsFixed(0)}';
    } else {
      deliveryFee = 'LKR 0';
    }

    final String? image = pickCatalogImageUrl(map);
    final String category = (map['category'] as String?)?.trim().isNotEmpty == true
        ? (map['category'] as String).trim()
        : 'General';
    final String tag = (map['tag'] as String?)?.trim().isNotEmpty == true
        ? (map['tag'] as String).trim()
        : 'General';
    final String address = _pickStoreAddress(map);
    final String phone = _pickStorePhone(map);
    final String catalogKind =
        (map['catalogKind'] as String?)?.trim() ?? '';
    return SearchStore(
      id: id,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'Unnamed Store',
      category: category,
      tag: tag,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      eta: (map['eta'] as String?)?.trim().isNotEmpty == true
          ? map['eta'] as String
          : 'N/A',
      imageUrl: image ?? '',
      deliveryFee: deliveryFee,
      address: address,
      phone: phone,
      isOpen: vendorIsAcceptingOrders(map),
      catalogKind: catalogKind,
    );
  }
}

/// Customer-visible storefronts: approved shops (open or closed), plus legacy
/// docs without [approvalStatus] that are still `active`.
bool isCustomerVisibleVendor(Map<String, dynamic> map) {
  final String approval =
      ((map['approvalStatus'] as String?) ?? '').trim().toLowerCase();
  if (approval == 'pending' || approval == 'rejected') {
    return false;
  }
  if (approval == 'approved') {
    return true;
  }
  return map['active'] == true;
}

/// Whether a vendor Firestore doc is currently accepting orders.
bool vendorIsAcceptingOrders(Map<String, dynamic> map) {
  final dynamic active = map['active'];
  if (active is bool) {
    return active;
  }
  final dynamic raw = map['isOpen'] ?? map['open'] ?? map['is_open'];
  if (raw is bool) {
    return raw;
  }
  final String status = _trimmedString(map['status']).toLowerCase();
  if (status == 'closed' || status == 'inactive' || status == 'offline') {
    return false;
  }
  if (status == 'open' || status == 'active') {
    return true;
  }
  return true;
}

String _trimmedString(dynamic value) {
  if (value is! String) {
    return '';
  }
  return value.trim();
}

String _pickStoreAddress(Map<String, dynamic> map) {
  final String addressLine = _trimmedString(map['addressLine']);
  final String city = _trimmedString(map['city']);
  final List<String> parts = <String>[
    if (addressLine.isNotEmpty) addressLine,
    if (city.isNotEmpty) city,
  ];
  return parts.isEmpty ? '' : parts.join(', ');
}

String _pickStorePhone(Map<String, dynamic> map) {
  for (final String key in <String>[
    'phone',
    'phoneNumber',
    'contactPhone',
    'mobile',
    'tel',
  ]) {
    final String v = _trimmedString(map[key]);
    if (v.isNotEmpty) {
      return v;
    }
  }
  return '';
}

class SearchProductSizeOption {
  const SearchProductSizeOption({
    required this.name,
    required this.priceLkr,
  });

  final String name;
  final int priceLkr;
}

class SearchProduct {
  const SearchProduct({
    required this.documentId,
    required this.storeId,
    required this.lookupKey,
    required this.name,
    required this.storeName,
    required this.price,
    required this.imageUrl,
    required this.basePriceLkr,
    this.productCategory = '',
    this.sizeOptions = const <SearchProductSizeOption>[],
    this.manageStock = false,
    this.stockQty = 0,
  });

  final String documentId;
  final String storeId;
  final String lookupKey;
  final String name;
  final String storeName;
  final String price;
  final String imageUrl;
  final int basePriceLkr;

  /// Grocery aisle label from Firestore `productCategory` (empty for food / legacy).
  final String productCategory;

  /// Priced variants from Firestore `sizeOptions` (absolute LKR each). Empty for legacy products.
  final List<SearchProductSizeOption> sizeOptions;

  /// Vendor opted into stock tracking (`manageStock` on the product doc).
  final bool manageStock;

  /// On-hand units when [manageStock] is true.
  final int stockQty;

  /// False only when stock tracking is on and qty is zero.
  bool get isInStock => productAvailabilityFromMap(<String, dynamic>{
        'manageStock': manageStock,
        'stockQty': stockQty,
      });

  static List<SearchProductSizeOption> _parseSizeOptions(dynamic raw) {
    if (raw is! List) {
      return const <SearchProductSizeOption>[];
    }
    final List<SearchProductSizeOption> out = <SearchProductSizeOption>[];
    for (final dynamic row in raw) {
      if (row is! Map) {
        continue;
      }
      final Map<String, dynamic> m = Map<String, dynamic>.from(row);
      final String name = ((m['name'] as String?) ?? '').trim();
      if (name.isEmpty) {
        continue;
      }
      final dynamic p = m['priceLkr'] ?? m['price'];
      int lkr = 0;
      if (p is num) {
        lkr = p.round().clamp(0, 99999999);
      } else if (p is String) {
        lkr = int.tryParse(p.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      }
      out.add(SearchProductSizeOption(name: name, priceLkr: lkr));
    }
    return List<SearchProductSizeOption>.unmodifiable(out);
  }

  factory SearchProduct.fromFirestore(
    String documentId,
    Map<String, dynamic> map,
  ) {
    final List<SearchProductSizeOption> sizeOpts = _parseSizeOptions(map['sizeOptions']);

    int baseLkr = 0;
    String parsedPrice;
    if (sizeOpts.isNotEmpty) {
      baseLkr = sizeOpts
          .map((SearchProductSizeOption e) => e.priceLkr)
          .reduce((int a, int b) => a < b ? a : b);
      if (sizeOpts.length > 1) {
        parsedPrice = ProductPriceDisplay.format(baseLkr, from: true);
      } else {
        parsedPrice = ProductPriceDisplay.format(baseLkr);
      }
    } else {
      final dynamic rawPrice = map['price'];
      if (rawPrice is num) {
        baseLkr = rawPrice.round();
        parsedPrice = ProductPriceDisplay.format(baseLkr);
      } else if (rawPrice is String && rawPrice.trim().isNotEmpty) {
        parsedPrice = ProductPriceDisplay.normalize(rawPrice.trim());
        final String digits = rawPrice.replaceAll(RegExp(r'[^\d]'), '');
        baseLkr = int.tryParse(digits) ?? 0;
      } else {
        parsedPrice = ProductPriceDisplay.format(0);
      }
    }

    final String storeId = ((map['storeId'] as String?) ?? '').trim();
    final String rawLookup = ((map['lookupKey'] as String?) ?? '').trim().toLowerCase();
    final String lookupKey =
        rawLookup.isNotEmpty ? rawLookup : documentId.trim().toLowerCase();

    final String? img = pickCatalogImageUrl(map);

    final dynamic rawStock = map['stockQty'];
    final int stockQty = rawStock is num ? rawStock.round().clamp(0, 9999999) : 0;

    return SearchProduct(
      documentId: documentId,
      storeId: storeId,
      lookupKey: lookupKey,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'Unnamed Product',
      storeName: (map['storeName'] as String?)?.trim().isNotEmpty == true
          ? map['storeName'] as String
          : ((map['vendorName'] as String?) ?? 'Unknown Store'),
      price: parsedPrice,
      imageUrl: img ?? '',
      basePriceLkr: baseLkr,
      productCategory: ((map['productCategory'] as String?) ?? '').trim(),
      sizeOptions: sizeOpts,
      manageStock: map['manageStock'] == true,
      stockQty: stockQty,
    );
  }
}

final StateProvider<String> customerSearchQueryProvider = StateProvider<String>((Ref ref) {
  return '';
});

/// Home / Food / Grocery browse windows (keep small for web cold & scroll cost).
const int kBrowseVendorQueryLimit = 80;
const int kBrowseVendorDisplayLimit = 24;
const int kBrowseProductQueryLimit = 64;

/// Search / All Shops / catalog warm — capped so snapshots stay bounded.
const int kSearchCatalogLimit = 200;

List<SearchStore> _mapVisibleStores(
  QuerySnapshot<Map<String, dynamic>> snapshot, {
  int? displayLimit,
}) {
  final List<SearchStore> visible = snapshot.docs
      .where(
        (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            isCustomerVisibleVendor(doc.data()),
      )
      .map(
        (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            SearchStore.fromFirestore(doc.id, doc.data()),
      )
      .toList(growable: false);
  if (displayLimit == null || visible.length <= displayLimit) {
    return visible;
  }
  return visible.take(displayLimit).toList(growable: false);
}

List<SearchProduct> _mapActiveProducts(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  return snapshot.docs
      .map(
        (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            SearchProduct.fromFirestore(doc.id, doc.data()),
      )
      .toList(growable: false);
}

/// Search / All Shops — capped vendor list (not unbounded).
final StreamProvider<List<SearchStore>> storesStreamProvider =
    StreamProvider<List<SearchStore>>((Ref ref) {
  final firestore = ref.watch(firestoreProvider);
  // Do not require `active == true` here: open-hours sync flips `active` for
  // closed shops, but approved storefronts must still appear (as Closed).
  return firestore
      .collection(FirebaseCollections.vendors)
      .limit(kSearchCatalogLimit)
      .snapshots()
      .map(_mapVisibleStores);
});

/// Bounded vendor list for home / food / grocery browse hubs.
final StreamProvider<List<SearchStore>> homeNearbyStoresStreamProvider =
    StreamProvider<List<SearchStore>>((Ref ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirebaseCollections.vendors)
      .limit(kBrowseVendorQueryLimit)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snapshot) => _mapVisibleStores(
          snapshot,
          displayLimit: kBrowseVendorDisplayLimit,
        ),
      );
});

/// Alias — same browse window as home (shared listener when both watched).
final StreamProvider<List<SearchStore>> browseStoresStreamProvider =
    homeNearbyStoresStreamProvider;

/// Search catalog — capped active products (not unbounded).
final StreamProvider<List<SearchProduct>> productsStreamProvider =
    StreamProvider<List<SearchProduct>>((Ref ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirebaseCollections.products)
      .where('active', isEqualTo: true)
      .limit(kSearchCatalogLimit)
      .snapshots()
      .map(_mapActiveProducts);
});

/// Bounded product feed for home Recommended / food / grocery hubs.
final StreamProvider<List<SearchProduct>> homeFeedProductsStreamProvider =
    StreamProvider<List<SearchProduct>>((Ref ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirebaseCollections.products)
      .where('active', isEqualTo: true)
      .limit(kBrowseProductQueryLimit)
      .snapshots()
      .map(_mapActiveProducts);
});

/// Alias — same browse window as home recommended feed.
final StreamProvider<List<SearchProduct>> browseProductsStreamProvider =
    homeFeedProductsStreamProvider;

/// Single vendor doc — avoids pulling the catalog for store details / deep links.
final StreamProviderFamily<SearchStore?, String> vendorDocStreamProvider =
    StreamProvider.family<SearchStore?, String>((Ref ref, String storeId) {
  final String id = storeId.trim();
  if (id.isEmpty) {
    return Stream<SearchStore?>.value(null);
  }
  final FirebaseFirestore firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirebaseCollections.vendors)
      .doc(id)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> snap) {
    final Map<String, dynamic>? data = snap.data();
    if (!snap.exists || data == null || !isCustomerVisibleVendor(data)) {
      return null;
    }
    return SearchStore.fromFirestore(snap.id, data);
  });
});

/// Active catalog for one vendor store (customer store details / menu).
final StreamProviderFamily<List<SearchProduct>, String> storeActiveProductsStreamProvider =
    StreamProvider.family<List<SearchProduct>, String>((Ref ref, String storeId) {
  final FirebaseFirestore firestore = ref.watch(firestoreProvider);
  final String id = storeId.trim();
  if (id.isEmpty) {
    return Stream<List<SearchProduct>>.value(const <SearchProduct>[]);
  }
  return firestore
      .collection(FirebaseCollections.products)
      .where('storeId', isEqualTo: id)
      .where('active', isEqualTo: true)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
    final List<SearchProduct> list = snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              SearchProduct.fromFirestore(doc.id, doc.data()),
        )
        .toList(growable: false);
    list.sort(
      (SearchProduct a, SearchProduct b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return list;
  });
});

/// Store menu: prefer dedicated store query; seed instantly from warm catalog.
final ProviderFamily<AsyncValue<List<SearchProduct>>, String> storeMenuProductsProvider =
    Provider.family<AsyncValue<List<SearchProduct>>, String>((Ref ref, String storeId) {
  final String id = storeId.trim();
  final AsyncValue<List<SearchProduct>> storeAsync =
      ref.watch(storeActiveProductsStreamProvider(id));
  if (storeAsync.hasValue) {
    return storeAsync;
  }
  // Seed from browse feed only — never subscribe to the larger search catalog.
  final List<SearchProduct>? warm =
      ref.watch(browseProductsStreamProvider).valueOrNull;
  if (warm != null) {
    final List<SearchProduct> seeded = warm
        .where((SearchProduct p) => p.storeId == id)
        .toList()
      ..sort(
        (SearchProduct a, SearchProduct b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    if (seeded.isNotEmpty) {
      return AsyncValue<List<SearchProduct>>.data(seeded);
    }
  }
  return storeAsync;
});

final Provider<List<SearchStore>> filteredStoresProvider = Provider<List<SearchStore>>((Ref ref) {
  final String query = ref.watch(customerSearchQueryProvider).trim().toLowerCase();
  final List<SearchStore> stores = ref.watch(storesStreamProvider).maybeWhen(
        data: (items) => items,
        orElse: () => const <SearchStore>[],
      );
  if (query.isEmpty) {
    return stores;
  }
  return stores
      .where(
        (store) =>
            store.name.toLowerCase().contains(query) ||
            store.tag.toLowerCase().contains(query) ||
            store.category.toLowerCase().contains(query),
      )
      .toList(growable: false);
});

final Provider<List<SearchProduct>> filteredProductsProvider =
    Provider<List<SearchProduct>>((Ref ref) {
  final String query = ref.watch(customerSearchQueryProvider).trim().toLowerCase();
  final List<SearchProduct> products = ref.watch(productsStreamProvider).maybeWhen(
        data: (items) => items,
        orElse: () => const <SearchProduct>[],
      );
  if (query.isEmpty) {
    return products;
  }
      return products
      .where(
        (product) =>
            product.name.toLowerCase().contains(query) ||
            product.storeName.toLowerCase().contains(query) ||
            product.lookupKey.toLowerCase().contains(query),
      )
      .toList(growable: false);
});
