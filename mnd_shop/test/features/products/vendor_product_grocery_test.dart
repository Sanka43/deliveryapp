import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/products/domain/vendor_grocery_catalog.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';

void main() {
  group('isGroceryVendorCategoryTag', () {
    test('detects grocery / supermarket / pharmacy', () {
      expect(
        isGroceryVendorCategoryTag(category: 'Grocery', tag: 'Mini mart'),
        isTrue,
      );
      expect(
        isGroceryVendorCategoryTag(category: 'Food', tag: 'supermarket'),
        isTrue,
      );
      expect(
        isGroceryVendorCategoryTag(category: 'Pharmacy', tag: 'Store'),
        isTrue,
      );
      expect(
        isGroceryVendorCategoryTag(category: 'General', tag: 'Mini mart'),
        isTrue,
      );
      expect(
        isGroceryVendorCategoryTag(category: 'Food', tag: 'Restaurant'),
        isFalse,
      );
      expect(
        isGroceryVendorCategoryTag(category: 'Grosery', tag: 'Mini mart'),
        isTrue,
      );
    });
  });

  group('isGroceryVendorDoc', () {
    test('explicit catalogKind grocery wins', () {
      expect(
        isGroceryVendorDoc(<String, dynamic>{
          'catalogKind': 'grocery',
          'category': 'Food',
          'tag': 'Restaurant',
        }),
        isTrue,
      );
    });

    test('stale catalogKind food does not hide Mini mart tag', () {
      expect(
        isGroceryVendorDoc(<String, dynamic>{
          'catalogKind': 'food',
          'category': 'Food',
          'tag': 'Mini mart',
        }),
        isTrue,
      );
      expect(
        isGroceryVendorDoc(<String, dynamic>{
          'catalogKind': 'food',
          'category': 'General',
          'tag': 'supermarket',
        }),
        isTrue,
      );
    });

    test('Grosery typo category still counts as grocery', () {
      expect(
        isGroceryVendorDoc(<String, dynamic>{
          'catalogKind': 'food',
          'category': 'Grosery',
          'tag': 'Store',
        }),
        isTrue,
      );
      expect(
        vendorCatalogKindFromFields(categoryLabel: 'Grosery'),
        'grocery',
      );
      expect(normalizeVendorCategoryLabel('Grosery'), 'Grocery');
      expect(normalizeVendorCategoryLabel('Grocery'), 'Grocery');
    });

    test('catalogKind food with restaurant stays food', () {
      expect(
        isGroceryVendorDoc(<String, dynamic>{
          'catalogKind': 'food',
          'category': 'Food',
          'tag': 'Restaurant',
        }),
        isFalse,
      );
    });

    test('legacy docs without catalogKind use category/tag', () {
      expect(
        isGroceryVendorDoc(<String, dynamic>{
          'category': 'Grocery',
          'tag': 'Store',
        }),
        isTrue,
      );
      expect(
        isGroceryVendorDoc(<String, dynamic>{
          'category': 'Food',
          'tag': 'Cafe',
        }),
        isFalse,
      );
    });
  });

  group('vendorCatalogKindFromFields', () {
    test('uses tag when category alone is food', () {
      expect(
        vendorCatalogKindFromFields(
          categoryLabel: 'Food',
          tag: 'Mini mart',
        ),
        'grocery',
      );
      expect(
        vendorCatalogKindFromFields(
          categoryLabel: 'Food',
          tag: 'Restaurant',
        ),
        'food',
      );
      expect(
        vendorCatalogKindFromFields(categoryLabel: 'Grocery'),
        'grocery',
      );
    });
  });

  group('VendorProduct productCategory', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('fromDoc parses productCategory and sizeOptions packs', () async {
      await firestore.collection(FirebaseCollections.products).doc('p1').set(
        <String, dynamic>{
          'storeId': 's1',
          'storeName': 'Mart',
          'name': 'Milk 1L',
          'description': 'Full cream',
          'price': 450,
          'imageUrl': '',
          'lookupKey': 'milk_p1',
          'active': true,
          'stockQty': 12,
          'eta': 'Ready now',
          'productCategory': 'Dairy',
          'sizeOptions': <Map<String, dynamic>>[
            <String, dynamic>{'name': '500g', 'priceLkr': 250},
            <String, dynamic>{'name': '1L', 'priceLkr': 450},
          ],
        },
      );

      final DocumentSnapshot<Map<String, dynamic>> doc =
          await firestore.collection(FirebaseCollections.products).doc('p1').get();
      final VendorProduct p = VendorProduct.fromDoc(doc);

      expect(p.productCategory, 'Dairy');
      expect(p.sizeOptions, hasLength(2));
      expect(p.sizeOptions.first.name, '500g');
      expect(p.sizeOptions.last.priceLkr, 450);
    });

    test('toFirestore writes productCategory', () {
      const VendorProduct p = VendorProduct(
        id: 'p1',
        storeId: 's1',
        storeName: 'Mart',
        name: 'Bread',
        description: '',
        priceLkr: 120,
        imageUrl: '',
        lookupKey: 'bread_p1',
        active: true,
        stockQty: 4,
        manageStock: true,
        etaLabel: 'Ready now',
        productCategory: 'Bakery',
        sizeOptions: <ProductSizeOption>[
          ProductSizeOption(name: 'Pack of 6', priceLkr: 120),
        ],
      );

      final Map<String, dynamic> map =
          p.toFirestore(storeName: 'Mart', lookupKey: 'bread_p1');
      expect(map['productCategory'], 'Bakery');
      expect(map['manageStock'], isTrue);
      expect(map['sizeOptions'], isA<List<dynamic>>());
      expect((map['sizeOptions'] as List<dynamic>).first['name'], 'Pack of 6');
    });

    test('manageStock defaults false when missing; true when set', () async {
      await firestore.collection(FirebaseCollections.products).doc('p0').set(
        <String, dynamic>{
          'storeId': 's1',
          'name': 'Rice',
          'price': 100,
          'stockQty': 0,
          'active': true,
        },
      );
      await firestore.collection(FirebaseCollections.products).doc('p2').set(
        <String, dynamic>{
          'storeId': 's1',
          'name': 'Milk',
          'price': 200,
          'stockQty': 0,
          'manageStock': true,
          'active': true,
        },
      );

      final VendorProduct unmanaged = VendorProduct.fromDoc(
        await firestore.collection(FirebaseCollections.products).doc('p0').get(),
      );
      final VendorProduct managed = VendorProduct.fromDoc(
        await firestore.collection(FirebaseCollections.products).doc('p2').get(),
      );

      expect(unmanaged.manageStock, isFalse);
      expect(unmanaged.stockQty, 0);
      expect(managed.manageStock, isTrue);
      expect(managed.stockQty, 0);
    });
  });
}
