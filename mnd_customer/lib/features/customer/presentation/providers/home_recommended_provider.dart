import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/food_catalog_provider.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';

/// Why a product landed in Recommended.
enum RecommendReason { topRated, nearby, forYou }

extension RecommendReasonLabel on RecommendReason {
  String get label {
    switch (this) {
      case RecommendReason.topRated:
        return 'Top rated';
      case RecommendReason.nearby:
        return 'Nearby';
      case RecommendReason.forYou:
        return 'For you';
    }
  }
}

class RecommendedPick {
  const RecommendedPick({
    required this.product,
    required this.reason,
  });

  final SearchProduct product;
  final RecommendReason reason;
}

/// New seed each cold start so the rail reshuffles when the app opens.
final homeRecommendSessionSeedProvider = Provider<int>((Ref ref) {
  return DateTime.now().millisecondsSinceEpoch;
});

int? _etaMinutes(String eta) {
  final Match? m = RegExp(r'(\d+)').firstMatch(eta);
  if (m == null) {
    return null;
  }
  return int.tryParse(m.group(1)!);
}

/// Builds a mixed pool (top-rated / nearby / past-order stores), then shuffles
/// with the session seed so each app open shows a different set.
final homeRecommendedPicksProvider = Provider<AsyncValue<List<RecommendedPick>>>(
  (Ref ref) {
    final AsyncValue<List<SearchProduct>> productsAsync =
        ref.watch(homeFeedProductsStreamProvider);
    final AsyncValue<List<SearchStore>> storesAsync =
        ref.watch(homeNearbyStoresStreamProvider);
    final List<CustomerOrderSummary> orders =
        ref.watch(customerOrdersStreamProvider).asData?.value ??
            const <CustomerOrderSummary>[];
    final int seed = ref.watch(homeRecommendSessionSeedProvider);

    return productsAsync.when(
      loading: () => const AsyncValue<List<RecommendedPick>>.loading(),
      error: (Object e, StackTrace st) =>
          AsyncValue<List<RecommendedPick>>.error(e, st),
      data: (List<SearchProduct> products) {
        if (products.isEmpty) {
          return const AsyncValue<List<RecommendedPick>>.data(
            <RecommendedPick>[],
          );
        }

        final List<SearchStore> stores = storesAsync.asData?.value ??
            const <SearchStore>[];
        final Map<String, SearchStore> storeById = <String, SearchStore>{
          for (final SearchStore s in stores) s.id: s,
        };

        // Top-rated: rating >= 4, else top third by rating.
        final List<SearchStore> rated = List<SearchStore>.from(stores)
          ..sort(
            (SearchStore a, SearchStore b) => b.rating.compareTo(a.rating),
          );
        final Set<String> topRatedIds = rated
            .where((SearchStore s) => s.rating >= 4.0)
            .map((SearchStore s) => s.id)
            .toSet();
        if (topRatedIds.isEmpty && rated.isNotEmpty) {
          final int take = (rated.length / 3).ceil().clamp(1, rated.length);
          topRatedIds.addAll(rated.take(take).map((SearchStore s) => s.id));
        }

        // Nearby: lowest ETA minutes, else first half of store list.
        final List<SearchStore> byEta = stores.where((SearchStore s) {
          return _etaMinutes(s.eta) != null;
        }).toList()
          ..sort(
            (SearchStore a, SearchStore b) =>
                (_etaMinutes(a.eta) ?? 999).compareTo(_etaMinutes(b.eta) ?? 999),
          );
        final Set<String> nearbyIds = <String>{};
        if (byEta.isNotEmpty) {
          final int take = (byEta.length / 2).ceil().clamp(1, byEta.length);
          nearbyIds.addAll(byEta.take(take).map((SearchStore s) => s.id));
        } else if (stores.isNotEmpty) {
          final int take = (stores.length / 2).ceil().clamp(1, stores.length);
          nearbyIds.addAll(stores.take(take).map((SearchStore s) => s.id));
        }

        final Set<String> preferredStoreNames = orders
            .where((CustomerOrderSummary o) => o.statusRaw == 'delivered')
            .take(5)
            .map((CustomerOrderSummary o) => o.storeName.toLowerCase().trim())
            .where((String n) => n.isNotEmpty)
            .toSet();

        final List<RecommendedPick> topPool = <RecommendedPick>[];
        final List<RecommendedPick> nearbyPool = <RecommendedPick>[];
        final List<RecommendedPick> forYouPool = <RecommendedPick>[];
        final List<RecommendedPick> restPool = <RecommendedPick>[];

        for (final SearchProduct p in products) {
          if (p.storeId.isEmpty || p.imageUrl.trim().isEmpty) {
            continue;
          }
          final SearchStore? store = storeById[p.storeId];
          // Home Recommended is food-only — skip grocery / unknown vendors.
          if (store == null || !isFoodStore(store)) {
            continue;
          }
          final bool forYou = preferredStoreNames.contains(
            p.storeName.toLowerCase().trim(),
          );
          final bool top = topRatedIds.contains(p.storeId) ||
              store.rating >= 4.0;
          final bool near = nearbyIds.contains(p.storeId);

          if (forYou) {
            forYouPool.add(
              RecommendedPick(product: p, reason: RecommendReason.forYou),
            );
          } else if (top) {
            topPool.add(
              RecommendedPick(product: p, reason: RecommendReason.topRated),
            );
          } else if (near) {
            nearbyPool.add(
              RecommendedPick(product: p, reason: RecommendReason.nearby),
            );
          } else {
            restPool.add(
              RecommendedPick(product: p, reason: RecommendReason.nearby),
            );
          }
        }

        final Random rng = Random(seed);

        List<RecommendedPick> shuffleCopy(List<RecommendedPick> src) {
          final List<RecommendedPick> copy = List<RecommendedPick>.from(src);
          copy.shuffle(rng);
          return copy;
        }

        // Round-robin from shuffled pools so one open never looks identical.
        final List<List<RecommendedPick>> buckets = <List<RecommendedPick>>[
          shuffleCopy(forYouPool),
          shuffleCopy(topPool),
          shuffleCopy(nearbyPool),
          shuffleCopy(restPool),
        ];
        final List<int> cursors = List<int>.filled(buckets.length, 0);
        final List<RecommendedPick> mixed = <RecommendedPick>[];
        final Set<String> seen = <String>{};

        bool tookAny = true;
        while (mixed.length < 12 && tookAny) {
          tookAny = false;
          for (int b = 0; b < buckets.length; b++) {
            while (cursors[b] < buckets[b].length) {
              final RecommendedPick pick = buckets[b][cursors[b]++];
              final String key = pick.product.lookupKey.isNotEmpty
                  ? pick.product.lookupKey
                  : pick.product.documentId;
              if (seen.add(key)) {
                mixed.add(pick);
                tookAny = true;
                break;
              }
            }
            if (mixed.length >= 12) {
              break;
            }
          }
        }

        mixed.shuffle(rng);
        return AsyncValue<List<RecommendedPick>>.data(mixed);
      },
    );
  },
);
