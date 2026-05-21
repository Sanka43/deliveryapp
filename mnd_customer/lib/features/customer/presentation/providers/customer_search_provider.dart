import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/utils/catalog_image_url.dart';
import 'package:mnd_delivery_app/core/utils/product_price_display.dart';

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
      imageUrl: image != null && image.isNotEmpty
          ? image
          : 'https://images.unsplash.com/photo-1542838132-92c53300491e?q=80&w=600&auto=format&fit=crop',
      deliveryFee: deliveryFee,
      address: address,
      phone: phone,
    );
  }
}

String _trimmedString(dynamic value) {
  if (value is! String) {
    return '';
  }
  return value.trim();
}

String _pickStoreAddress(Map<String, dynamic> map) {
  final String direct = _trimmedString(map['address']);
  if (direct.isNotEmpty) {
    return direct;
  }
  final String locationName = _trimmedString(map['locationName']);
  if (locationName.isNotEmpty) {
    return locationName;
  }
  final String street = _trimmedString(map['street']);
  final String city = _trimmedString(map['city']);
  final String line1 = _trimmedString(map['addressLine1']);
  final List<String> parts = <String>[
    if (line1.isNotEmpty) line1,
    if (street.isNotEmpty) street,
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
    this.sizeOptions = const <SearchProductSizeOption>[],
  });

  final String documentId;
  final String storeId;
  final String lookupKey;
  final String name;
  final String storeName;
  final String price;
  final String imageUrl;
  final int basePriceLkr;

  /// Priced variants from Firestore `sizeOptions` (absolute LKR each). Empty for legacy products.
  final List<SearchProductSizeOption> sizeOptions;

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
      imageUrl: img != null && img.isNotEmpty
          ? img
          : 'https://images.unsplash.com/photo-1563636619-e9143da7973b?q=80&w=600&auto=format&fit=crop',
      basePriceLkr: baseLkr,
      sizeOptions: sizeOpts,
    );
  }
}

final StateProvider<String> customerSearchQueryProvider = StateProvider<String>((Ref ref) {
  return '';
});

final StreamProvider<List<SearchStore>> storesStreamProvider =
    StreamProvider<List<SearchStore>>((Ref ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirebaseCollections.vendors)
      .where('active', isEqualTo: true)
      .snapshots()
      .map(
    (snapshot) {
      return snapshot.docs
          .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final String? approval = doc.data()['approvalStatus'] as String?;
            if (approval == 'pending' || approval == 'rejected') {
              return false;
            }
            return true;
          })
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                SearchStore.fromFirestore(doc.id, doc.data()),
          )
          .toList(growable: false);
    },
  );
});

final StreamProvider<List<SearchProduct>> productsStreamProvider =
    StreamProvider<List<SearchProduct>>((Ref ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirebaseCollections.products)
      .where('active', isEqualTo: true)
      .snapshots()
      .map(
    (snapshot) {
      return snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                SearchProduct.fromFirestore(doc.id, doc.data()),
          )
          .toList(growable: false);
    },
  );
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
