import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/utils/product_price_display.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_empty_state.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_brand_watermark.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/cart/presentation/widgets/floating_cart_summary_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/store/store_offers_section.dart';
import 'package:mnd_delivery_app/features/offers/presentation/providers/customer_offers_provider.dart';
import 'package:mnd_delivery_app/features/store/domain/product_availability.dart';
import 'package:mnd_delivery_app/features/store/presentation/widgets/product_details_bottom_sheet.dart';

class StoreDetailsPage extends ConsumerWidget {
  const StoreDetailsPage({
    required this.storeId,
    required this.storeName,
    required this.imageUrl,
    required this.tag,
    required this.rating,
    required this.eta,
    required this.deliveryFee,
    this.storeAddress = '',
    this.storePhone = '',
    super.key,
  });

  final String storeId;
  final String storeName;
  final String imageUrl;
  final String tag;
  final double rating;
  final String eta;
  final String deliveryFee;
  final String storeAddress;
  final String storePhone;

  /// Prefer route query image; fall back to live vendor doc for deep links.
  String _resolvedHeroImageUrl(WidgetRef ref) {
    final String fromRoute = imageUrl.trim();
    if (fromRoute.isNotEmpty) {
      return fromRoute;
    }
    return _vendorFromStream(ref)?.imageUrl.trim() ?? '';
  }

  SearchStore? _vendorFromStream(WidgetRef ref) {
    if (storeId.isEmpty) {
      return null;
    }
    return ref.watch(vendorDocStreamProvider(storeId.trim())).asData?.value;
  }

  String _resolvedStoreName(WidgetRef ref) {
    final String fromRoute = storeName.trim();
    if (fromRoute.isNotEmpty) {
      return fromRoute;
    }
    return _vendorFromStream(ref)?.name.trim() ?? '';
  }

  String _resolvedTag(WidgetRef ref) {
    final String fromRoute = tag.trim();
    if (fromRoute.isNotEmpty) {
      return fromRoute;
    }
    return _vendorFromStream(ref)?.tag.trim() ?? '';
  }

  String _resolvedEta(WidgetRef ref) {
    final String fromRoute = eta.trim();
    if (fromRoute.isNotEmpty) {
      return fromRoute;
    }
    return _vendorFromStream(ref)?.eta.trim() ?? '';
  }

  String _resolvedDeliveryFee(WidgetRef ref) {
    final String fromRoute = deliveryFee.trim();
    if (fromRoute.isNotEmpty) {
      return fromRoute;
    }
    return _vendorFromStream(ref)?.deliveryFee.trim() ?? '';
  }

  String _resolvedAddress(WidgetRef ref) {
    final String fromRoute = storeAddress.trim();
    if (fromRoute.isNotEmpty) {
      return fromRoute;
    }
    return _vendorFromStream(ref)?.address.trim() ?? '';
  }

  String _resolvedPhone(WidgetRef ref) {
    final String fromRoute = storePhone.trim();
    if (fromRoute.isNotEmpty) {
      return fromRoute;
    }
    return _vendorFromStream(ref)?.phone.trim() ?? '';
  }

  double _resolvedRating(WidgetRef ref) {
    if (rating > 0) {
      return rating;
    }
    return _vendorFromStream(ref)?.rating ?? 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CartState cart = ref.watch(cartProvider);
    final bool showFloatingCart =
        !cart.isEmpty && cart.items.isNotEmpty && cart.items.first.storeId == storeId;
    const double floatingCartReserve = 88;
    final String heroImageUrl = _resolvedHeroImageUrl(ref);
    final String resolvedStoreName = _resolvedStoreName(ref);
    final String resolvedTag = _resolvedTag(ref);
    final String resolvedEta = _resolvedEta(ref);
    final String resolvedDeliveryFee = _resolvedDeliveryFee(ref);
    final String resolvedAddress = _resolvedAddress(ref);
    final String resolvedPhone = _resolvedPhone(ref);
    final double resolvedRating = _resolvedRating(ref);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            final Color onBar =
                innerBoxIsScrolled ? Theme.of(context).colorScheme.onSurface : Colors.white;
            return <Widget>[
              SliverAppBar(
                pinned: true,
                expandedHeight: 272,
                elevation: innerBoxIsScrolled ? 1 : 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                backgroundColor: innerBoxIsScrolled
                    ? Theme.of(context).scaffoldBackgroundColor
                    : Colors.transparent,
                foregroundColor: onBar,
                iconTheme: IconThemeData(color: onBar),
                actionsIconTheme: IconThemeData(color: onBar),
                systemOverlayStyle: innerBoxIsScrolled
                    ? SystemUiOverlayStyle.dark
                    : SystemUiOverlayStyle.light,
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: innerBoxIsScrolled ? 1 : 0,
                  child: Text(
                    resolvedStoreName.isNotEmpty ? resolvedStoreName : 'Store',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      MndNetworkImage(
                        imageUrl: heroImageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorChild: Container(
                          color: AppColors.primaryBlue.withValues(alpha: 0.12),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: const FittedBox(
                            fit: BoxFit.contain,
                            child: MndBrandWatermark(
                              mndFontSize: 56,
                              subtitleFontSize: 15,
                              mndOpacity: 0.22,
                              subtitleOpacity: 0.17,
                            ),
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: <Color>[
                              Colors.black.withValues(alpha: 0.72),
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                            stops: const <double>[0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SafeArea(
                          top: false,
                          minimum: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              28,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            child: _StoreHeroOverlay(
                              storeName: resolvedStoreName,
                              address: resolvedAddress,
                              phone: resolvedPhone,
                              rating: resolvedRating,
                              tag: resolvedTag,
                              eta: resolvedEta,
                              deliveryFee: resolvedDeliveryFee,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: Padding(
            padding: EdgeInsets.only(
              bottom: showFloatingCart ? floatingCartReserve : 0,
            ),
            child: ref.watch(storeMenuProductsProvider(storeId)).when(
                  data: (List<SearchProduct> items) {
                    final List<StoreMenuProduct> products = items
                        .map(StoreMenuProduct.fromSearchProduct)
                        .toList(growable: false);
                    final bool hasOffers = ref
                            .watch(storeLiveOffersProvider(storeId))
                            .asData
                            ?.value
                            .isNotEmpty ??
                        false;
                    if (products.isEmpty && !hasOffers) {
                      return const _StoreMenuEmptyState();
                    }
                    if (products.isEmpty) {
                      return ListView(
                        padding: EdgeInsets.zero,
                        children: <Widget>[
                          StoreOffersSection(storeId: storeId),
                          const SizedBox(height: AppSpacing.lg),
                          const _StoreMenuEmptyState(),
                        ],
                      );
                    }
                    return _StoreProductList(
                      storeId: storeId,
                      storeName: resolvedStoreName,
                      products: products,
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (Object err, StackTrace _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        userFacingError(
                          err,
                          fallback: 'Could not load menu. Please try again.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
          ),
        ),
        if (showFloatingCart)
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
                child: FloatingCartSummaryBar(
                  filterStoreId: storeId,
                  onViewCart: () => context.push(AppRoutes.customerCart),
                ),
              ),
          ],
        ),
    );
  }
}

class _StoreMenuEmptyState extends StatelessWidget {
  const _StoreMenuEmptyState();

  @override
  Widget build(BuildContext context) {
    return MndEmptyState(
      icon: Icons.restaurant_menu_rounded,
      title: 'No items on the menu yet',
      subtitle: 'This store has not published any active products.',
      actionLabel: 'Browse stores',
      onAction: () => context.go(AppRoutes.customer),
    );
  }
}

class _StoreMenuProductRow extends StatelessWidget {
  const _StoreMenuProductRow({
    required this.item,
    required this.priceLabel,
    required this.isAvailable,
    required this.onTap,
  });

  final StoreMenuProduct item;
  final String priceLabel;
  final bool isAvailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ColoredBox(
                        color: AppColors.homeMutedFill,
                        child: MndNetworkImage(
                          imageUrl: item.imageUrl,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (!isAvailable)
                        ColoredBox(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isAvailable
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      priceLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: isAvailable ? AppColors.brandPrimary : AppColors.homeMutedFill,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: isAvailable ? onTap : null,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.add_rounded,
                      color: isAvailable ? Colors.white : AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!isAvailable) {
      return Opacity(opacity: 0.55, child: row);
    }
    return row;
  }
}

class _StoreHeroOverlay extends StatelessWidget {
  const _StoreHeroOverlay({
    required this.storeName,
    required this.address,
    required this.phone,
    required this.rating,
    required this.tag,
    required this.eta,
    required this.deliveryFee,
  });

  final String storeName;
  final String address;
  final String phone;
  final double rating;
  final String tag;
  final String eta;
  final String deliveryFee;

  String _metaLine() {
    final List<String> parts = <String>[];
    if (tag.trim().isNotEmpty) {
      parts.add(tag.trim());
    }
    if (eta.trim().isNotEmpty) {
      parts.add(eta.trim());
    }
    if (deliveryFee.trim().isNotEmpty) {
      parts.add('Delivery ${deliveryFee.trim()}');
    }
    return parts.join(' · ');
  }

  static List<Shadow> get _textShadow => <Shadow>[
        Shadow(
          color: Colors.black.withValues(alpha: 0.55),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle whiteTitle = textTheme.headlineSmall!.copyWith(
      fontWeight: FontWeight.w800,
      color: Colors.white,
      letterSpacing: -0.4,
      height: 1.15,
      shadows: _textShadow,
    );
    final TextStyle whiteLine = textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 0.95),
      height: 1.35,
      shadows: _textShadow,
    );
    final TextStyle whiteMeta = textTheme.labelMedium!.copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.white.withValues(alpha: 0.88),
      height: 1.2,
      shadows: _textShadow,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          storeName.isNotEmpty ? storeName : 'Store',
          style: whiteTitle,
        ),
        if (address.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(address.trim(), style: whiteLine)),
            ],
          ),
        ],
        if (phone.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(
                Icons.phone_outlined,
                size: 17,
                color: Colors.white.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(phone.trim(), style: whiteLine),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            if (rating > 0) ...<Widget>[
              const Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
              const SizedBox(width: 2),
              Text(rating.toStringAsFixed(1), style: whiteMeta),
            ],
            if (_metaLine().isNotEmpty) ...<Widget>[
              if (rating > 0) Text('  ·  ', style: whiteMeta),
              Expanded(
                child: Text(
                  _metaLine(),
                  style: whiteMeta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StoreProductList extends ConsumerWidget {
  const _StoreProductList({
    required this.products,
    required this.storeId,
    required this.storeName,
  });

  final List<StoreMenuProduct> products;
  final String storeId;
  final String storeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, ProductAvailabilityInfo>> availabilityAsync =
        ref.watch(storeProductAvailabilityProvider(storeId));
    final bool storeOpen =
        ref.watch(storeAcceptingOrdersProvider(storeId)).asData?.value ?? true;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: products.length + 1 + (storeOpen ? 0 : 1),
      separatorBuilder: (BuildContext context, int index) {
        if (index == 0 || (!storeOpen && index == 1)) {
          return const SizedBox.shrink();
        }
        return Divider(
          height: 1,
          thickness: 1,
          color: AppColors.homeMutedFill.withValues(alpha: 0.9),
        );
      },
      itemBuilder: (BuildContext context, int index) {
        int cursor = index;
        if (!storeOpen) {
          if (cursor == 0) {
            return Material(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.storefront_outlined,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This shop is closed right now. You can browse, but ordering is paused.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          cursor -= 1;
        }
        if (cursor == 0) {
          return StoreOffersSection(storeId: storeId, insetHorizontal: false);
        }
        final StoreMenuProduct item = products[cursor - 1];
        final bool isAvailable = availabilityAsync.when(
          data: (Map<String, ProductAvailabilityInfo> availabilityMap) =>
              availabilityMap[item.lookupKey]?.isAvailable ?? true,
          loading: () => true,
          error: (_, __) => true,
        );

        return _StoreMenuProductRow(
          item: item,
          priceLabel: _formatRs(item.basePrice),
          isAvailable: isAvailable && storeOpen,
          onTap: () {
            if (!storeOpen) {
              showShopClosedSnackBar(context);
              return;
            }
            showProductDetailsBottomSheet(
              context: context,
              ref: ref,
              item: item,
              storeId: storeId,
              storeName: storeName,
            );
          },
        );
      },
    );
  }

  String _formatRs(int amount) => ProductPriceDisplay.format(amount);
}

/// Live stock snapshot for one product — [isAvailable] mirrors the same
/// precedence chain used everywhere else (`isAvailable`/`inStock`/`active`
/// then `manageStock`+`stockQty`); [stockQty] is only meaningful when
/// [manageStock] is true.
class ProductAvailabilityInfo {
  const ProductAvailabilityInfo({
    required this.isAvailable,
    required this.manageStock,
    required this.stockQty,
  });

  final bool isAvailable;
  final bool manageStock;
  final int stockQty;
}

ProductAvailabilityInfo _parseAvailabilityInfo(Map<String, dynamic> map) {
  final dynamic rawStock = map['stockQty'];
  final int stockQty =
      rawStock is num ? rawStock.round().clamp(0, 9999999) : 0;
  return ProductAvailabilityInfo(
    isAvailable: _parseAvailability(map),
    manageStock: map['manageStock'] == true,
    stockQty: stockQty,
  );
}

final storeProductAvailabilityProvider = StreamProvider.family<
    Map<String, ProductAvailabilityInfo>, String>((Ref ref, String storeId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirebaseCollections.products)
      .where('storeId', isEqualTo: storeId)
      .snapshots()
      .map((snapshot) {
    final Map<String, ProductAvailabilityInfo> availability =
        <String, ProductAvailabilityInfo>{};
    for (final doc in snapshot.docs) {
      final Map<String, dynamic> map = doc.data();
      final String key = _getProductLookupKey(doc.id, map);
      if (key.isEmpty) {
        continue;
      }
      availability[key] = _parseAvailabilityInfo(map);
    }
    return availability;
  });
});

String _getProductLookupKey(String docId, Map<String, dynamic> map) {
  final String rawKey = ((map['lookupKey'] as String?) ?? '').trim().toLowerCase();
  if (rawKey.isNotEmpty) {
    return rawKey;
  }

  final String productId = ((map['productId'] as String?) ?? '').trim().toLowerCase();
  if (productId.isNotEmpty) {
    return productId;
  }

  final String docKey = docId.trim().toLowerCase();
  if (docKey.isNotEmpty) {
    return docKey;
  }

  final String name = ((map['name'] as String?) ?? '').trim().toLowerCase();
  return name.replaceAll(' ', '_');
}

bool _parseAvailability(Map<String, dynamic> map) {
  return productAvailabilityFromMap(map);
}

/// Live vendor accepting-orders flag (`active` / open status).
final storeAcceptingOrdersProvider =
    StreamProvider.family<bool, String>((Ref ref, String storeId) {
  final String id = storeId.trim();
  if (id.isEmpty) {
    return Stream<bool>.value(false);
  }
  return ref
      .watch(firestoreProvider)
      .collection(FirebaseCollections.vendors)
      .doc(id)
      .snapshots()
      .map((snap) {
    final Map<String, dynamic>? map = snap.data();
    if (map == null) {
      return false;
    }
    return vendorIsAcceptingOrders(map);
  });
});
