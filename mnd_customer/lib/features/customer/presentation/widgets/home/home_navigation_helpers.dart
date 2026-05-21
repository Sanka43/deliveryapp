import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/home_recent_searches_provider.dart';

void openCustomerSearch(
  BuildContext context, {
  String? query,
  bool saveRecent = false,
}) {
  if (query != null && query.trim().isNotEmpty) {
    // Provider will be set by caller via ref when available.
  }
  context.go(AppRoutes.customerSearch);
}

void seedSearchQuery(WidgetRef ref, String query) {
  ref.read(customerSearchQueryProvider.notifier).state = query;
}

Future<void> navigateToSearchWithQuery(
  WidgetRef ref,
  BuildContext context,
  String query, {
  bool saveRecent = true,
}) async {
  if (saveRecent) {
    await ref.read(homeRecentSearchesProvider.notifier).addSearch(query);
  }
  seedSearchQuery(ref, query);
  if (context.mounted) {
    context.go(AppRoutes.customerSearch);
  }
}

void openStoreDetails(BuildContext context, SearchStore store) {
  final Map<String, String> queryParameters = <String, String>{
    'name': store.name,
    'imageUrl': store.imageUrl,
    'tag': store.tag,
    'rating': store.rating.toString(),
    'eta': store.eta,
    'deliveryFee': store.deliveryFee,
  };
  if (store.address.isNotEmpty) {
    queryParameters['address'] = store.address;
  }
  if (store.phone.isNotEmpty) {
    queryParameters['phone'] = store.phone;
  }
  context.push(
    Uri(
      path: '${AppRoutes.customerStoreDetails}/${store.id}',
      queryParameters: queryParameters,
    ).toString(),
  );
}

void openStoreMenuForProductChoice(
  BuildContext context,
  WidgetRef ref,
  SearchProduct item,
) {
  final SearchStore? store = ref.read(storesStreamProvider).maybeWhen(
        data: (List<SearchStore> list) {
          for (final SearchStore s in list) {
            if (s.id == item.storeId) {
              return s;
            }
          }
          return null;
        },
        orElse: () => null,
      );
  if (store == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Find this shop under Search, then open the menu to choose size and plate options.',
        ),
      ),
    );
    return;
  }
  openStoreDetails(context, store);
}

bool addProductToCart(BuildContext context, WidgetRef ref, SearchProduct item) {
  if (item.sizeOptions.isNotEmpty) {
    openStoreMenuForProductChoice(context, ref, item);
    return false;
  }
  final bool added = ref.read(cartProvider.notifier).addItem(
        CartItem(
          productKey: item.lookupKey,
          productName: item.name,
          storeId: item.storeId,
          storeName: item.storeName,
          imageUrl: item.imageUrl,
          selectedSize: 'Standard',
          quantity: 1,
          basePrice: item.basePriceLkr,
          sizePriceDelta: 0,
        ),
      );
  if (!context.mounted) {
    return added;
  }
  if (!added) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Cart has items from another store. Open cart and clear it first, or add from the same store.',
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).clearSnackBars();
  }
  return added;
}

String catalogLoadErrorMessage(Object error) {
  final String raw = error.toString();
  if (raw.contains('permission-denied')) {
    return 'Could not load catalog (permission denied). Deploy updated Firestore rules or sign in.';
  }
  if (raw.length > 280) {
    return '${raw.substring(0, 280)}…';
  }
  return raw;
}
