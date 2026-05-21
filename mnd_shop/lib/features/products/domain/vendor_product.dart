import 'package:cloud_firestore/cloud_firestore.dart';

/// One priced menu line (absolute LKR). Shown as a size/portion choice in the customer app.
class ProductSizeOption {
  const ProductSizeOption({
    required this.name,
    required this.priceLkr,
  });

  final String name;
  final int priceLkr;
}

/// Product row aligned with customer app `SearchProduct.fromFirestore` fields.
class VendorProduct {
  const VendorProduct({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.name,
    required this.description,
    required this.priceLkr,
    required this.imageUrl,
    required this.lookupKey,
    required this.active,
    required this.stockQty,
    required this.etaLabel,
    this.sizeOptions = const <ProductSizeOption>[],
  });

  final String id;
  final String storeId;
  final String storeName;
  final String name;
  final String description;
  final int priceLkr;
  final String imageUrl;
  final String lookupKey;
  final bool active;
  /// On-hand units (missing in older docs → 0).
  final int stockQty;
  /// Product-level ETA text (e.g. 10-15 min).
  final String etaLabel;

  /// Optional priced variants. When non-empty, [priceLkr] should be the minimum option price.
  final List<ProductSizeOption> sizeOptions;

  factory VendorProduct.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> map = doc.data() ?? <String, dynamic>{};
    final dynamic rawPrice = map['price'];
    int price = 0;
    if (rawPrice is num) {
      price = rawPrice.round();
    } else if (rawPrice is String) {
      price = int.tryParse(rawPrice.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    }

    final String rawLookup =
        ((map['lookupKey'] as String?) ?? '').trim().toLowerCase();
    final String lookup =
        rawLookup.isNotEmpty ? rawLookup : doc.id.trim().toLowerCase();

    final dynamic rawStock = map['stockQty'];
    int stock = 0;
    if (rawStock is num) {
      stock = rawStock.round().clamp(0, 9999999);
    }

    final List<ProductSizeOption> options = _parseSizeOptions(map['sizeOptions']);

    return VendorProduct(
      id: doc.id,
      storeId: ((map['storeId'] as String?) ?? '').trim(),
      storeName: (map['storeName'] as String?)?.trim().isNotEmpty == true
          ? map['storeName'] as String
          : ((map['vendorName'] as String?) ?? 'Store'),
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'Unnamed',
      description: ((map['description'] as String?) ?? '').trim(),
      priceLkr: price,
      imageUrl: ((map['imageUrl'] as String?) ?? '').trim(),
      lookupKey: lookup,
      active: map['active'] is bool ? map['active'] as bool : true,
      stockQty: stock,
      etaLabel: ((map['eta'] as String?) ?? '').trim(),
      sizeOptions: options,
    );
  }

  static List<ProductSizeOption> _parseSizeOptions(dynamic raw) {
    if (raw is! List) {
      return const <ProductSizeOption>[];
    }
    final List<ProductSizeOption> out = <ProductSizeOption>[];
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
      out.add(ProductSizeOption(name: name, priceLkr: lkr));
    }
    return List<ProductSizeOption>.unmodifiable(out);
  }

  Map<String, dynamic> toFirestore({
    required String storeName,
    required String lookupKey,
  }) {
    return <String, dynamic>{
      'storeId': storeId,
      'storeName': storeName,
      'name': name,
      'description': description,
      'price': priceLkr,
      'imageUrl': imageUrl,
      'lookupKey': lookupKey,
      'active': active,
      'stockQty': stockQty,
      'eta': etaLabel,
      'sizeOptions': sizeOptions
          .map(
            (ProductSizeOption e) => <String, dynamic>{
              'name': e.name,
              'priceLkr': e.priceLkr,
            },
          )
          .toList(growable: false),
    };
  }
}
