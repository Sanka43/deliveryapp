import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_banners_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/home_recent_searches_provider.dart';

/// Shown whenever ordering is attempted while the shop is closed.
const String kShopClosedMessage = 'This shop is closed right now.';

void openCustomerSearch(
  BuildContext context, {
  String? query,
  bool saveRecent = false,
}) {
  if (query != null && query.trim().isNotEmpty) {
    // Provider will be set by caller via ref when available.
  }
  context.push(AppRoutes.customerSearch);
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
    context.push(AppRoutes.customerSearch);
  }
}

/// Looks up a store in browse / search catalogs, then a direct vendor doc cache.
SearchStore? findCatalogStore(WidgetRef ref, String storeId) {
  final String id = storeId.trim();
  if (id.isEmpty) {
    return null;
  }
  SearchStore? fromList(AsyncValue<List<SearchStore>> async) {
    return async.maybeWhen(
      data: (List<SearchStore> list) {
        for (final SearchStore s in list) {
          if (s.id == id) {
            return s;
          }
        }
        return null;
      },
      orElse: () => null,
    );
  }

  return fromList(ref.read(browseStoresStreamProvider)) ??
      fromList(ref.read(storesStreamProvider)) ??
      ref.read(vendorDocStreamProvider(id)).valueOrNull;
}

/// Returns false when the catalog knows this shop and it is closed.
/// Unknown / not-yet-loaded stores are treated as open so other gates apply.
bool isStoreOpenInCatalog(WidgetRef ref, String storeId) {
  final SearchStore? store = findCatalogStore(ref, storeId);
  if (store == null) {
    return true;
  }
  return store.isOpen;
}

void showShopClosedSnackBar(BuildContext context) {
  showMndSnackBar(context, kShopClosedMessage, variant: MndSnackBarVariant.warning);
}

/// Opens store details for browsing. Closed shops are allowed; ordering is
/// paused on the details page and other add-to-cart entry points.
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

/// Resolves banner `targetRoute` / `targetStoreId` / `targetQuery` taps.
void openCustomerBannerTarget(
  BuildContext context,
  CustomerBanner banner, {
  WidgetRef? ref,
}) {
  final String? storeId = banner.targetStoreId;
  if (storeId != null && storeId.isNotEmpty) {
    if (ref != null) {
      final SearchStore? known = findCatalogStore(ref, storeId);
      if (known != null) {
        openStoreDetails(context, known);
        return;
      }
    }
    context.push('${AppRoutes.customerStoreDetails}/$storeId');
    return;
  }
  final String? query = banner.targetQuery;
  if (query != null && query.isNotEmpty) {
    context.push(
      '${AppRoutes.customerSearch}?q=${Uri.encodeComponent(query)}',
    );
    return;
  }
  final String raw = (banner.targetRoute ?? '').trim().toLowerCase();
  if (raw.isEmpty) {
    openCustomerSearch(context);
    return;
  }
  if (raw.startsWith('/')) {
    context.go(raw);
    return;
  }
  switch (raw) {
    case 'food':
      context.go(AppRoutes.customerFood);
    case 'grocery':
      context.go(AppRoutes.customerGrocery);
    case 'rides':
      context.go(AppRoutes.customerRides);
    case 'jobs':
      context.go(AppRoutes.customerJobs);
    case 'shops':
      context.go(AppRoutes.customerShops);
    default:
      openCustomerSearch(context);
  }
}

void openStoreMenuForProductChoice(
  BuildContext context,
  WidgetRef ref,
  SearchProduct item,
) {
  final SearchStore? store = findCatalogStore(ref, item.storeId);
  if (store == null) {
    showMndSnackBar(
      context,
      'Find this shop under Search, then open the menu to choose size and plate options.',
    );
    return;
  }
  openStoreDetails(context, store);
}

bool addProductToCart(BuildContext context, WidgetRef ref, SearchProduct item) {
  if (!isStoreOpenInCatalog(ref, item.storeId)) {
    if (context.mounted) {
      showShopClosedSnackBar(context);
    }
    return false;
  }
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
    showMndSnackBar(
      context,
      'Cart has items from another store. Open cart and clear it first, or add from the same store.',
      variant: MndSnackBarVariant.warning,
    );
  } else {
    MndSnackBar.clear(context);
  }
  return added;
}

String catalogLoadErrorMessage(Object error) {
  return userFacingError(
    error,
    fallback: 'Could not load shops right now. Please try again.',
  );
}
