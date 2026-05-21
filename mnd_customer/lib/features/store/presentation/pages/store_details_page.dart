import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/utils/product_price_display.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_brand_watermark.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/cart/presentation/widgets/floating_cart_summary_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CartState cart = ref.watch(cartProvider);
    final bool showFloatingCart =
        !cart.isEmpty && cart.items.isNotEmpty && cart.items.first.storeId == storeId;
    const double floatingCartReserve = 88;

    return DefaultTabController(
      length: 1,
      child: Scaffold(
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
                    storeName,
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
                        imageUrl: imageUrl,
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
                              storeName: storeName,
                              address: storeAddress,
                              phone: storePhone,
                              rating: rating,
                              tag: tag,
                              eta: eta,
                              deliveryFee: deliveryFee,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    tabs: <Tab>[
                      Tab(text: 'Menu'),
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
            child: ref.watch(storeActiveProductsStreamProvider(storeId)).when(
                  data: (List<SearchProduct> items) {
                    final List<_StoreProduct> products =
                        items.map(_storeProductFromSearchProduct).toList(growable: false);
                    return TabBarView(
                      children: <Widget>[
                        products.isEmpty
                            ? const _StoreMenuEmptyState()
                            : _StoreProductList(
                                storeId: storeId,
                                storeName: storeName,
                                eta: eta,
                                products: products,
                              ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (Object err, StackTrace _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Could not load menu.\n$err',
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
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return false;
  }
}

class _StoreMenuEmptyState extends StatelessWidget {
  const _StoreMenuEmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        const SizedBox(height: 48),
        Icon(
          Icons.restaurant_menu_rounded,
          size: 56,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'No items on the menu yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'This store has not published any active products.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }
}

_StoreProduct _storeProductFromSearchProduct(SearchProduct p) {
  final List<_VariationOption> sizes = p.sizeOptions.isEmpty
      ? const <_VariationOption>[]
      : p.sizeOptions
          .map(
            (SearchProductSizeOption o) => _VariationOption(
              name: o.name,
              priceDelta: o.priceLkr - p.basePriceLkr,
            ),
          )
          .toList(growable: false);
  return _StoreProduct(
    name: p.name,
    lookupKey: p.lookupKey,
    basePrice: p.basePriceLkr,
    imageUrl: p.imageUrl,
    sizes: sizes,
    extras: const <_VariationOption>[],
  );
}

bool _storeMenuEtaVisible(String eta) {
  final String trimmed = eta.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  return trimmed.toLowerCase() != 'n/a';
}

class _StoreMenuProductRow extends StatelessWidget {
  const _StoreMenuProductRow({
    required this.item,
    required this.eta,
    required this.priceLabel,
    required this.isAvailable,
    required this.onTap,
  });

  final _StoreProduct item;
  final String eta;
  final String priceLabel;
  final bool isAvailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool showEta = _storeMenuEtaVisible(eta);

    final Widget row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                          showWatermarkOnError: false,
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isAvailable
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    if (showEta) ...<Widget>[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              eta.trim(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      priceLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
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

  static List<Shadow> get _textShadow => <Shadow>[
        Shadow(
          color: Colors.black.withValues(alpha: 0.55),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final TextStyle whiteTitle = GoogleFonts.plusJakartaSans(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      letterSpacing: -0.4,
      height: 1.15,
      shadows: _textShadow,
    );
    final TextStyle whiteLine = GoogleFonts.plusJakartaSans(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 0.95),
      height: 1.35,
      shadows: _textShadow,
    );
    final TextStyle whiteMeta = GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.white.withValues(alpha: 0.88),
      height: 1.2,
      shadows: _textShadow,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(storeName, style: whiteTitle),
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
            Icon(Icons.star_rounded, color: Colors.amber.shade300, size: 18),
            const SizedBox(width: 2),
            Text(rating.toStringAsFixed(1), style: whiteMeta),
            Text('  ·  ', style: whiteMeta),
            Expanded(
              child: Text(
                '$tag · $eta · Delivery $deliveryFee',
                style: whiteMeta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
    required this.eta,
  });

  final List<_StoreProduct> products;
  final String storeId;
  final String storeName;
  final String eta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, bool>> availabilityAsync =
        ref.watch(storeProductAvailabilityProvider(storeId));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: products.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 1,
        color: AppColors.homeMutedFill.withValues(alpha: 0.9),
      ),
      itemBuilder: (BuildContext context, int index) {
        final _StoreProduct item = products[index];
        final bool isAvailable = availabilityAsync.when(
          data: (Map<String, bool> availabilityMap) =>
              availabilityMap[item.lookupKey] ?? true,
          loading: () => true,
          error: (_, __) => true,
        );

        return _StoreMenuProductRow(
          item: item,
          eta: eta,
          priceLabel: _formatRs(item.basePrice),
          isAvailable: isAvailable,
          onTap: () => _showProductDetailsBottomSheet(context, ref, item),
        );
      },
    );
  }

  void _showProductDetailsBottomSheet(
    BuildContext context,
    WidgetRef ref,
    _StoreProduct item,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        int quantity = 1;
        final List<_VariationOption> availableSizes = item.sizes.isEmpty
            ? const <_VariationOption>[
                _VariationOption(name: 'Standard', priceDelta: 0),
              ]
            : item.sizes;
        int selectedSizeIndex = 0;
        final Set<int> selectedExtraIndexes = <int>{};
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setModalState) {
            final _VariationOption selectedSize = availableSizes[selectedSizeIndex];
            final int extrasTotal = selectedExtraIndexes.fold<int>(
              0,
              (int sum, int index) => sum + item.extras[index].priceDelta,
            );
            final int unitPrice = item.basePrice + selectedSize.priceDelta + extrasTotal;
            final int totalPrice = unitPrice * quantity;

            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AspectRatio(
                          aspectRatio: 1.15,
                          child: MndNetworkImage(
                            imageUrl: item.imageUrl,
                            fit: BoxFit.cover,
                            errorChild: ColoredBox(
                              color: AppColors.primaryBlue.withValues(alpha: 0.08),
                              child: const Center(
                                child: MndBrandWatermark(
                                  mndFontSize: 38,
                                  subtitleFontSize: 11,
                                  mndOpacity: 0.24,
                                  subtitleOpacity: 0.18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        item.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.9,
                          height: 1.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        storeName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (availableSizes.length > 1) ...<Widget>[
                        Text(
                          'Choose size',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: List<Widget>.generate(availableSizes.length, (int index) {
                            final _VariationOption option = availableSizes[index];
                            final bool selected = selectedSizeIndex == index;
                            return ChoiceChip(
                              label: Text(
                                option.priceDelta == 0
                                    ? option.name
                                    : '${option.name} (${_formatLkr(option.priceDelta, signed: true)})',
                              ),
                              selected: selected,
                              onSelected: (_) {
                                setModalState(() {
                                  selectedSizeIndex = index;
                                });
                              },
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (item.extras.isNotEmpty) ...<Widget>[
                        Text(
                          'Extras',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...List<Widget>.generate(item.extras.length, (int index) {
                          final _VariationOption option = item.extras[index];
                          final bool selected = selectedExtraIndexes.contains(index);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: selected,
                            onChanged: (bool? value) {
                              setModalState(() {
                                if (value == true) {
                                  selectedExtraIndexes.add(index);
                                } else {
                                  selectedExtraIndexes.remove(index);
                                }
                              });
                            },
                            title: Text(option.name),
                            subtitle: Text(_formatLkr(option.priceDelta, signed: true)),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Text(
                            'Quantity',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: quantity > 1
                                ? () {
                                    setModalState(() {
                                      quantity--;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$quantity',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setModalState(() {
                                quantity++;
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Text(
                            'Total price',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 31,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: AppColors.textPrimary,
                              height: 1.0,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatLkr(totalPrice),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 31,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: AppColors.textPrimary,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                        onPressed: () {
                          final List<CartExtra> selectedExtras = selectedExtraIndexes
                              .map((int index) => item.extras[index])
                              .map(
                                (extra) => CartExtra(
                                  name: extra.name,
                                  priceDelta: extra.priceDelta,
                                ),
                              )
                              .toList(growable: false);

                          final bool added = ref.read(cartProvider.notifier).addItem(
                                CartItem(
                                  productKey: item.lookupKey,
                                  productName: item.name,
                                  storeId: storeId,
                                  storeName: storeName,
                                  imageUrl: item.imageUrl,
                                  selectedSize: selectedSize.name,
                                  quantity: quantity,
                                  basePrice: item.basePrice,
                                  sizePriceDelta: selectedSize.priceDelta,
                                  extras: selectedExtras,
                                ),
                              );

                          if (!added) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You can only add items from one store at a time. Clear cart first.',
                                ),
                              ),
                            );
                            return;
                          }

                          ScaffoldMessenger.of(context).clearSnackBars();
                          Navigator.of(context).pop();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
                        label: Text('Add to Cart (${quantity}x)'),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatRs(int amount) => ProductPriceDisplay.format(amount);

  String _formatLkr(int amount, {bool signed = false}) {
    if (!signed || amount == 0) {
      return 'LKR $amount';
    }
    final String sign = amount > 0 ? '+' : '-';
    return '$sign LKR ${amount.abs()}';
  }
}

class _StoreProduct {
  const _StoreProduct({
    required this.name,
    required this.lookupKey,
    required this.basePrice,
    required this.imageUrl,
    this.sizes = const <_VariationOption>[],
    this.extras = const <_VariationOption>[],
  });

  final String name;
  final String lookupKey;
  final int basePrice;
  final String imageUrl;
  final List<_VariationOption> sizes;
  final List<_VariationOption> extras;

}

class _VariationOption {
  const _VariationOption({
    required this.name,
    required this.priceDelta,
  });

  final String name;
  final int priceDelta;
}

final storeProductAvailabilityProvider =
    StreamProvider.family<Map<String, bool>, String>((Ref ref, String storeId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirebaseCollections.products)
      .where('storeId', isEqualTo: storeId)
      .snapshots()
      .map((snapshot) {
    final Map<String, bool> availability = <String, bool>{};
    for (final doc in snapshot.docs) {
      final Map<String, dynamic> map = doc.data();
      final String key = _getProductLookupKey(doc.id, map);
      if (key.isEmpty) {
        continue;
      }
      availability[key] = _parseAvailability(map);
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
  final dynamic stockQty = map['stockQty'];
  if (stockQty is num && stockQty.round() <= 0) {
    return false;
  }
  final dynamic isAvailable = map['isAvailable'];
  if (isAvailable is bool) {
    return isAvailable;
  }
  final dynamic inStock = map['inStock'];
  if (inStock is bool) {
    return inStock;
  }
  final dynamic active = map['active'];
  if (active is bool) {
    return active;
  }
  return true;
}
