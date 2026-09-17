import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/products/data/vendor_product_repository.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';

void main() {
  group('VendorProductRepository inventory', () {
    late FakeFirebaseFirestore firestore;
    late VendorProductRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = VendorProductRepository(
        firestore: firestore,
        storage: MockFirebaseStorage(),
      );
    });

    Future<void> seedProduct(
      String id, {
      int stockQty = 5,
      bool active = true,
      String storeId = 'store-1',
      bool manageStock = true,
    }) async {
      await firestore
          .collection(FirebaseCollections.products)
          .doc(id)
          .set(<String, dynamic>{
            'storeId': storeId,
            'storeName': 'Store',
            'name': id,
            'description': '',
            'price': 100,
            'imageUrl': '',
            'lookupKey': id,
            'active': active,
            'stockQty': stockQty,
            'manageStock': manageStock,
          });
    }

    test('setProductStock updates quantity and records movement', () async {
      await seedProduct('p1', stockQty: 4);

      await repo.setProductStock(
        productId: 'p1',
        quantity: 9,
        reason: 'test_set',
      );

      final Map<String, dynamic>? product =
          (await firestore
                  .collection(FirebaseCollections.products)
                  .doc('p1')
                  .get())
              .data();
      expect(product?['stockQty'], 9);

      final movements = await firestore
          .collection(FirebaseCollections.products)
          .doc('p1')
          .collection('stock_movements')
          .get();
      expect(movements.docs, hasLength(1));
      expect(movements.docs.first.data()['previousQty'], 4);
      expect(movements.docs.first.data()['nextQty'], 9);
      expect(movements.docs.first.data()['delta'], 5);
      expect(movements.docs.first.data()['reason'], 'test_set');
    });

    test('adjustProductStock clamps at zero and records movement', () async {
      await seedProduct('p1', stockQty: 3);

      await repo.adjustProductStock(
        productId: 'p1',
        delta: -10,
        reason: 'test_adjust',
      );

      final Map<String, dynamic>? product =
          (await firestore
                  .collection(FirebaseCollections.products)
                  .doc('p1')
                  .get())
              .data();
      expect(product?['stockQty'], 0);

      final movements = await firestore
          .collection(FirebaseCollections.products)
          .doc('p1')
          .collection('stock_movements')
          .get();
      expect(movements.docs.first.data()['previousQty'], 3);
      expect(movements.docs.first.data()['nextQty'], 0);
      expect(movements.docs.first.data()['delta'], -3);
      expect(movements.docs.first.data()['reason'], 'test_adjust');
    });

    test(
      'setManyProductStock updates multiple products and logs each',
      () async {
        await seedProduct('p1', stockQty: 1);
        await seedProduct('p2', stockQty: 2);

        await repo.setManyProductStock(
          quantitiesByProductId: <String, int>{'p1': 8, 'p2': 0},
          reason: 'bulk_test',
        );

        final Map<String, dynamic>? p1 =
            (await firestore
                    .collection(FirebaseCollections.products)
                    .doc('p1')
                    .get())
                .data();
        final Map<String, dynamic>? p2 =
            (await firestore
                    .collection(FirebaseCollections.products)
                    .doc('p2')
                    .get())
                .data();
        expect(p1?['stockQty'], 8);
        expect(p2?['stockQty'], 0);

        final p1Movements = await firestore
            .collection(FirebaseCollections.products)
            .doc('p1')
            .collection('stock_movements')
            .get();
        final p2Movements = await firestore
            .collection(FirebaseCollections.products)
            .doc('p2')
            .collection('stock_movements')
            .get();
        expect(p1Movements.docs.single.data()['reason'], 'bulk_test');
        expect(p2Movements.docs.single.data()['reason'], 'bulk_test');
      },
    );

    test(
      'autoHideOutOfStockProducts hides only zero-stock products in store',
      () async {
        await seedProduct('out-1', stockQty: 0, active: true);
        await seedProduct('in-1', stockQty: 2, active: true);
        await seedProduct(
          'other-store',
          stockQty: 0,
          active: true,
          storeId: 'store-2',
        );

        await repo.autoHideOutOfStockProducts('store-1');

        final Map<String, dynamic>? out =
            (await firestore
                    .collection(FirebaseCollections.products)
                    .doc('out-1')
                    .get())
                .data();
        final Map<String, dynamic>? inStock =
            (await firestore
                    .collection(FirebaseCollections.products)
                    .doc('in-1')
                    .get())
                .data();
        final Map<String, dynamic>? other =
            (await firestore
                    .collection(FirebaseCollections.products)
                    .doc('other-store')
                    .get())
                .data();
        expect(out?['active'], isFalse);
        expect(inStock?['active'], isTrue);
        expect(other?['active'], isTrue);
      },
    );
  });

  group('VendorProductRepository nameExistsInStore', () {
    late FakeFirebaseFirestore firestore;
    late VendorProductRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = VendorProductRepository(
        firestore: firestore,
        storage: MockFirebaseStorage(),
      );
    });

    Future<void> seedNamed(String id, String name, {String storeId = 'store-1'}) {
      return firestore
          .collection(FirebaseCollections.products)
          .doc(id)
          .set(<String, dynamic>{
            'storeId': storeId,
            'storeName': 'Store',
            'name': name,
            'description': '',
            'price': 100,
            'imageUrl': '',
            'lookupKey': id,
            'active': true,
            'stockQty': 1,
          });
    }

    test('is case/whitespace-insensitive within the same store', () async {
      await seedNamed('p1', 'Cheese Koththu');

      expect(
        await repo.nameExistsInStore(storeId: 'store-1', name: '  cheese koththu  '),
        isTrue,
      );
      expect(
        await repo.nameExistsInStore(storeId: 'store-1', name: 'Chicken Koththu'),
        isFalse,
      );
    });

    test('ignores a match from a different store', () async {
      await seedNamed('p1', 'Cheese Koththu', storeId: 'store-2');

      expect(
        await repo.nameExistsInStore(storeId: 'store-1', name: 'Cheese Koththu'),
        isFalse,
      );
    });

    test('excludes the product being edited', () async {
      await seedNamed('p1', 'Cheese Koththu');

      expect(
        await repo.nameExistsInStore(
          storeId: 'store-1',
          name: 'Cheese Koththu',
          excludingProductId: 'p1',
        ),
        isFalse,
      );
    });
  });

  group('VendorProductRepository create limit', () {
    late FakeFirebaseFirestore firestore;
    late VendorProductRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = VendorProductRepository(
        firestore: firestore,
        storage: MockFirebaseStorage(),
      );
    });

    Future<void> seedStoreProducts(String storeId, int count) async {
      for (int i = 0; i < count; i++) {
        await firestore
            .collection(FirebaseCollections.products)
            .doc('$storeId-p$i')
            .set(<String, dynamic>{
              'storeId': storeId,
              'storeName': 'Store',
              'name': 'Product $i',
              'description': '',
              'price': 100,
              'imageUrl': '',
              'lookupKey': 'product_${i}_$storeId',
              'active': true,
              'stockQty': 1,
            });
      }
    }

    test('countByStore returns products for that store only', () async {
      await seedStoreProducts('store-1', 3);
      await seedStoreProducts('store-2', 2);

      expect(await repo.countByStore('store-1'), 3);
      expect(await repo.countByStore('store-2'), 2);
      expect(await repo.countByStore(''), 0);
    });

    test('createProduct succeeds when under the per-shop cap', () async {
      await seedStoreProducts('store-1', vendorMaxProductsPerShop - 1);

      await repo.createProduct(
        productId: 'new-1',
        storeId: 'store-1',
        storeName: 'Store',
        name: 'Fresh item',
        description: '',
        priceLkr: 250,
        sizeOptions: const <ProductSizeOption>[],
        imageUrl: '',
        active: true,
        stockQty: 2,
        etaLabel: '10-15 min',
      );

      expect(await repo.countByStore('store-1'), vendorMaxProductsPerShop);
      final Map<String, dynamic>? created =
          (await firestore
                  .collection(FirebaseCollections.products)
                  .doc('new-1')
                  .get())
              .data();
      expect(created?['name'], 'Fresh item');
    });

    test('createProduct throws when store is already at the cap', () async {
      await seedStoreProducts('store-1', vendorMaxProductsPerShop);

      await expectLater(
        repo.createProduct(
          productId: 'overflow-1',
          storeId: 'store-1',
          storeName: 'Store',
          name: 'Too many',
          description: '',
          priceLkr: 100,
          sizeOptions: const <ProductSizeOption>[],
          imageUrl: '',
          active: true,
          stockQty: 1,
          etaLabel: '10-15 min',
        ),
        throwsA(isA<VendorProductLimitExceededException>()),
      );

      expect(await repo.countByStore('store-1'), vendorMaxProductsPerShop);
      expect(
        (await firestore
                .collection(FirebaseCollections.products)
                .doc('overflow-1')
                .get())
            .exists,
        isFalse,
      );
    });

    test('createProduct allows grocery cap via maxProducts', () async {
      await seedStoreProducts('store-1', vendorMaxProductsPerShop);

      await repo.createProduct(
        productId: 'groc-1',
        storeId: 'store-1',
        storeName: 'Mart',
        name: 'Rice 1kg',
        description: '',
        priceLkr: 300,
        sizeOptions: const <ProductSizeOption>[
          ProductSizeOption(name: '1kg', priceLkr: 300),
        ],
        imageUrl: '',
        active: true,
        stockQty: 8,
        etaLabel: 'Ready now',
        productCategory: 'Fresh Produce',
        maxProducts: vendorMaxGroceryProductsPerShop,
      );

      final Map<String, dynamic>? created =
          (await firestore
                  .collection(FirebaseCollections.products)
                  .doc('groc-1')
                  .get())
              .data();
      expect(created?['productCategory'], 'Fresh Produce');
      expect(await repo.countByStore('store-1'), vendorMaxProductsPerShop + 1);
    });

    test(
      'createProduct seeds and increments vendors/{storeId}.productCount',
      () async {
        await seedStoreProducts('store-1', 2);

        await repo.createProduct(
          productId: 'new-1',
          storeId: 'store-1',
          storeName: 'Store',
          name: 'Fresh item',
          description: '',
          priceLkr: 250,
          sizeOptions: const <ProductSizeOption>[],
          imageUrl: '',
          active: true,
          stockQty: 2,
          etaLabel: '10-15 min',
        );

        final Map<String, dynamic>? vendorDoc =
            (await firestore
                    .collection(FirebaseCollections.vendors)
                    .doc('store-1')
                    .get())
                .data();
        // 2 pre-existing (query-seeded) + the one just created.
        expect(vendorDoc?['productCount'], 3);
      },
    );

    test('deleteProduct decrements vendors/{storeId}.productCount', () async {
      await seedStoreProducts('store-1', 3);
      // Establish the counter the same way createProduct would.
      await repo.createProduct(
        productId: 'extra-1',
        storeId: 'store-1',
        storeName: 'Store',
        name: 'Extra item',
        description: '',
        priceLkr: 100,
        sizeOptions: const <ProductSizeOption>[],
        imageUrl: '',
        active: true,
        stockQty: 1,
        etaLabel: '10-15 min',
      );
      expect(
        (await firestore.collection(FirebaseCollections.vendors).doc('store-1').get())
            .data()?['productCount'],
        4,
      );

      final VendorProduct toDelete = VendorProduct.fromDoc(
        await firestore
            .collection(FirebaseCollections.products)
            .doc('extra-1')
            .get(),
      );
      await repo.deleteProduct(toDelete);

      final Map<String, dynamic>? vendorDoc =
          (await firestore
                  .collection(FirebaseCollections.vendors)
                  .doc('store-1')
                  .get())
              .data();
      expect(vendorDoc?['productCount'], 3);
      expect(await repo.countByStore('store-1'), 3);
    });
  });
}
