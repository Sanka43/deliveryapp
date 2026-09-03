import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/utils/money_format.dart';
import 'package:mnd_delivery_app/core/utils/product_option_labels.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_brand_watermark.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/store/presentation/pages/store_details_page.dart'
    show ProductAvailabilityInfo, storeProductAvailabilityProvider;

class ProductVariationOption {
  const ProductVariationOption({
    required this.name,
    required this.priceDelta,
  });

  final String name;
  final int priceDelta;
}

class StoreMenuProduct {
  const StoreMenuProduct({
    required this.name,
    required this.lookupKey,
    required this.basePrice,
    required this.imageUrl,
    this.sizes = const <ProductVariationOption>[],
    this.extras = const <ProductVariationOption>[],
    this.manageStock = false,
    this.stockQty = 0,
  });

  final String name;
  final String lookupKey;
  final int basePrice;
  final String imageUrl;
  final List<ProductVariationOption> sizes;
  final List<ProductVariationOption> extras;

  /// Snapshot at the moment the sheet opened — the sheet re-checks this
  /// live via [storeProductAvailabilityProvider] rather than trusting this
  /// forever, since it can go stale while the customer is still deciding.
  final bool manageStock;
  final int stockQty;

  factory StoreMenuProduct.fromSearchProduct(SearchProduct p) {
    final List<ProductVariationOption> sizes = p.sizeOptions.isEmpty
        ? const <ProductVariationOption>[]
        : p.sizeOptions
            .map(
              (SearchProductSizeOption o) => ProductVariationOption(
                name: o.name,
                priceDelta: o.priceLkr - p.basePriceLkr,
              ),
            )
            .toList(growable: false);
    return StoreMenuProduct(
      name: p.name,
      lookupKey: p.lookupKey,
      basePrice: p.basePriceLkr,
      imageUrl: p.imageUrl,
      sizes: sizes,
      extras: const <ProductVariationOption>[],
      manageStock: p.manageStock,
      stockQty: p.stockQty,
    );
  }
}

String _formatLkr(int amount, {bool signed = false}) {
  return MoneyFormat.lkr(amount, signed: signed, showDecimals: false);
}

Future<void> showProductDetailsBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required StoreMenuProduct item,
  required String storeId,
  required String storeName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return _ProductDetailsSheet(
        ref: ref,
        item: item,
        storeId: storeId,
        storeName: storeName,
      );
    },
  );
}

class _ProductDetailsSheet extends StatefulWidget {
  const _ProductDetailsSheet({
    required this.ref,
    required this.item,
    required this.storeId,
    required this.storeName,
  });

  final WidgetRef ref;
  final StoreMenuProduct item;
  final String storeId;
  final String storeName;

  @override
  State<_ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _TypeSelection {
  _TypeSelection({this.sizeIndex = 0, this.quantity = 1});
  int sizeIndex;
  int quantity;
}

class _ProductDetailsSheetState extends State<_ProductDetailsSheet> {
  static const double _sheetRadius = 28;

  late final List<ProductVariationOption> _availableSizes;
  late final List<ProductTypeGroup> _groups;
  late final Map<String, ProductTypeGroup> _groupByKey = <String, ProductTypeGroup>{
    for (final ProductTypeGroup g in _groups) g.type.toLowerCase(): g,
  };

  // Each selected type keeps its own size + quantity, so several types can
  // be added to the cart at once (e.g. Beef Medium x1 + Chicken x2).
  final Map<String, _TypeSelection> _selections = <String, _TypeSelection>{};

  final Set<int> _selectedExtraIndexes = <int>{};

  StoreMenuProduct get _item => widget.item;

  // The sheet's item is a static snapshot from whenever it was opened — this
  // subscription keeps stock live for as long as the sheet stays open, so a
  // customer who lingers on a decision can't add something that just sold
  // out, or overshoot what's actually left.
  ProviderSubscription<AsyncValue<Map<String, ProductAvailabilityInfo>>>?
      _availabilitySub;
  ProductAvailabilityInfo? _liveInfo;

  bool get _manageStockLive => _liveInfo?.manageStock ?? _item.manageStock;
  int get _stockQtyLive => _liveInfo?.stockQty ?? _item.stockQty;
  bool get _isAvailableLive => _liveInfo?.isAvailable ?? true;

  /// Null when stock isn't tracked for this item (no cap).
  int? get _remainingStock => _manageStockLive ? _stockQtyLive : null;

  @override
  void initState() {
    super.initState();
    _availableSizes = _item.sizes.isEmpty
        ? const <ProductVariationOption>[
            ProductVariationOption(name: 'Standard', priceDelta: 0),
          ]
        : _item.sizes;
    _groups = buildProductTypeGroups(
      _availableSizes.map((ProductVariationOption o) => o.name).toList(),
    );
    _availabilitySub = widget.ref.listenManual(
      storeProductAvailabilityProvider(widget.storeId),
      (
        AsyncValue<Map<String, ProductAvailabilityInfo>>? previous,
        AsyncValue<Map<String, ProductAvailabilityInfo>> next,
      ) {
        final ProductAvailabilityInfo? info =
            next.asData?.value[_item.lookupKey];
        if (mounted) {
          setState(() => _liveInfo = info);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _availabilitySub?.close();
    super.dispose();
  }

  ProductVariationOption _optionFor(ProductTypeGroup group, int sizeIndex) =>
      _availableSizes[group.sizes[sizeIndex].optionIndex];

  int get _totalSelectedQuantity => _selections.values
      .fold<int>(0, (int sum, _TypeSelection s) => sum + s.quantity);

  int _totalSelectedQuantityExcluding(String excludeKey) => _selections.entries
      .where((MapEntry<String, _TypeSelection> e) => e.key != excludeKey)
      .fold<int>(0, (int sum, MapEntry<String, _TypeSelection> e) => sum + e.value.quantity);

  void _toggleType(ProductTypeGroup group) {
    final String key = group.type.toLowerCase();
    if (!_selections.containsKey(key)) {
      final int? remaining = _remainingStock;
      if (remaining != null && remaining - _totalSelectedQuantity <= 0) {
        showMndSnackBar(
          context,
          'No more of this item in stock.',
          variant: MndSnackBarVariant.warning,
        );
        return;
      }
    }
    setState(() {
      if (_selections.containsKey(key)) {
        _selections.remove(key);
      } else {
        _selections[key] = _TypeSelection();
      }
    });
  }

  void _setTypeSize(ProductTypeGroup group, int sizeIndex) {
    final String key = group.type.toLowerCase();
    setState(() {
      _selections[key]?.sizeIndex = sizeIndex;
    });
  }

  /// Clamped against live remaining stock (summed across every selected
  /// type/size sharing this one product's stock pool) so a customer can't
  /// step past what's actually on hand.
  void _setTypeQuantity(ProductTypeGroup group, int quantity) {
    final String key = group.type.toLowerCase();
    int nextQuantity = quantity < 1 ? 1 : quantity;
    final int? remaining = _remainingStock;
    if (remaining != null) {
      final int maxForThisSelection =
          (remaining - _totalSelectedQuantityExcluding(key)).clamp(0, 1 << 30);
      if (maxForThisSelection <= 0) {
        return;
      }
      nextQuantity = nextQuantity.clamp(1, maxForThisSelection);
    }
    setState(() {
      _selections[key]?.quantity = nextQuantity;
    });
  }

  /// Cheapest price a customer can actually pick (basePrice is a raw admin
  /// field and can sit below every real size/type price, e.g. LKR 25 base
  /// with no LKR 25 option — so "From" must use this, not basePrice alone).
  int get _cheapestSelectablePrice => _availableSizes.fold<int>(
        _item.basePrice + _availableSizes.first.priceDelta,
        (int min, ProductVariationOption o) =>
            _item.basePrice + o.priceDelta < min
                ? _item.basePrice + o.priceDelta
                : min,
      );

  int get _extrasTotal => _selectedExtraIndexes.fold<int>(
        0,
        (int sum, int index) => sum + _item.extras[index].priceDelta,
      );

  int get _totalPrice {
    int total = 0;
    for (final MapEntry<String, _TypeSelection> entry in _selections.entries) {
      final ProductTypeGroup group = _groupByKey[entry.key]!;
      final ProductVariationOption option =
          _optionFor(group, entry.value.sizeIndex);
      total += (_item.basePrice + option.priceDelta + _extrasTotal) *
          entry.value.quantity;
    }
    return total;
  }

  int get _totalQuantity => _selections.values
      .fold<int>(0, (int sum, _TypeSelection s) => sum + s.quantity);

  bool get _canAddToCart => _selections.isNotEmpty && _isAvailableLive;

  void _addToCart() {
    final List<CartExtra> selectedExtras = _selectedExtraIndexes
        .map((int index) => _item.extras[index])
        .map(
          (ProductVariationOption extra) => CartExtra(
            name: extra.name,
            priceDelta: extra.priceDelta,
          ),
        )
        .toList(growable: false);

    final List<CartItem> items = <CartItem>[];
    for (final ProductTypeGroup group in _groups) {
      final _TypeSelection? selection = _selections[group.type.toLowerCase()];
      if (selection == null || selection.quantity <= 0) {
        continue;
      }
      final ProductVariationOption option =
          _optionFor(group, selection.sizeIndex);
      final String size = group.sizes[selection.sizeIndex].size;
      final String label =
          size.isEmpty ? group.type : '${group.type}$kTypeSizeSeparator$size';
      items.add(
        CartItem(
          productKey: _item.lookupKey,
          productName: _item.name,
          storeId: widget.storeId,
          storeName: widget.storeName,
          imageUrl: _item.imageUrl,
          selectedSize: label,
          quantity: selection.quantity,
          basePrice: _item.basePrice,
          sizePriceDelta: option.priceDelta,
          extras: selectedExtras,
        ),
      );
    }
    if (items.isEmpty) {
      return;
    }

    final bool added = widget.ref
        .read(cartProvider.notifier)
        .mergeItemsFromSameStore(widget.storeId, items);

    if (!added) {
      showMndSnackBar(
        context,
        'Cart has items from another store.',
        variant: MndSnackBarVariant.warning,
        actionLabel: 'Clear & add',
        onAction: () {
          widget.ref.read(cartProvider.notifier).clear();
          widget.ref
              .read(cartProvider.notifier)
              .mergeItemsFromSameStore(widget.storeId, items);
          if (context.mounted) {
            Navigator.of(context).maybePop();
          }
        },
      );
      return;
    }

    MndSnackBar.clear(context);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.68,
      minChildSize: 0.52,
      maxChildSize: 0.90,
      builder: (BuildContext context, ScrollController scrollController) {
        return Material(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_sheetRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              Expanded(
                child: CustomScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: _ProductDetailHero(
                        imageUrl: _item.imageUrl,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          <Widget>[
                            _TitleBlock(
                              name: _item.name,
                              storeName: widget.storeName,
                              unitPriceLabel:
                                  'From ${_formatLkr(_cheapestSelectablePrice)}',
                            ),
                            if (!_isAvailableLive) ...<Widget>[
                              const SizedBox(height: 8),
                              const _StockNotice(
                                text: 'Out of stock',
                                isWarning: true,
                              ),
                            ] else if (_remainingStock != null &&
                                _remainingStock! <= 5) ...<Widget>[
                              const SizedBox(height: 8),
                              _StockNotice(
                                text: _remainingStock == 0
                                    ? 'Out of stock'
                                    : 'Only $_remainingStock left',
                                isWarning: _remainingStock == 0,
                              ),
                            ],
                            const SizedBox(height: 14),
                            // No `·` (Type · Size) in any option name means
                            // these are flat pack sizes (e.g. 500g, 1kg),
                            // not a real food type dimension — label
                            // accordingly instead of the food-oriented
                            // "Choose type" wording.
                            _SectionLabel(
                              _groups.isNotEmpty &&
                                      _groups.every(
                                        (ProductTypeGroup g) =>
                                            !g.hasSizeChoice,
                                      )
                                  ? 'Choose size'
                                  : 'Choose type',
                            ),
                            const SizedBox(height: 8),
                            ...List<Widget>.generate(_groups.length, (int index) {
                              final ProductTypeGroup group = _groups[index];
                              final _TypeSelection? selection =
                                  _selections[group.type.toLowerCase()];
                              final bool selected = selection != null;
                              final ProductVariationOption option = _optionFor(
                                group,
                                selection?.sizeIndex ?? 0,
                              );
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == _groups.length - 1 ? 0 : 8,
                                ),
                                child: _TypeSelectionCard(
                                  group: group,
                                  selected: selected,
                                  sizeIndex: selection?.sizeIndex ?? 0,
                                  quantity: selection?.quantity ?? 1,
                                  unitPriceLabel: _formatLkr(
                                    _item.basePrice + option.priceDelta,
                                  ),
                                  onToggle: () => _toggleType(group),
                                  onSizeSelected: (int sizeIndex) =>
                                      _setTypeSize(group, sizeIndex),
                                  onQuantityChanged: (int quantity) =>
                                      _setTypeQuantity(group, quantity),
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            if (_item.extras.isNotEmpty) ...<Widget>[
                              const _SectionLabel('Extras'),
                              const SizedBox(height: 8),
                              ...List<Widget>.generate(_item.extras.length,
                                  (int index) {
                                final ProductVariationOption option =
                                    _item.extras[index];
                                final bool selected =
                                    _selectedExtraIndexes.contains(index);
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == _item.extras.length - 1
                                        ? 0
                                        : 6,
                                  ),
                                  child: _ExtraRow(
                                    name: option.name,
                                    priceLabel: _formatLkr(
                                      option.priceDelta,
                                      signed: true,
                                    ),
                                    selected: selected,
                                    onTap: () {
                                      setState(() {
                                        if (selected) {
                                          _selectedExtraIndexes.remove(index);
                                        } else {
                                          _selectedExtraIndexes.add(index);
                                        }
                                      });
                                    },
                                  ),
                                );
                              }),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _AddToCartBar(
                totalLabel: _formatLkr(_totalPrice),
                quantity: _totalQuantity,
                onAdd: _canAddToCart ? _addToCart : null,
                outOfStock: !_isAvailableLive,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductDetailHero extends StatefulWidget {
  const _ProductDetailHero({
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  State<_ProductDetailHero> createState() => _ProductDetailHeroState();
}

class _ProductDetailHeroState extends State<_ProductDetailHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceOffset;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bounceOffset = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.25,
          child: MndNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.cover,
            errorChild: ColoredBox(
              color: AppColors.homeMutedFill,
              child: const Center(
                child: MndBrandWatermark(
                  mndFontSize: 32,
                  subtitleFontSize: 10,
                  mndOpacity: 0.24,
                  subtitleOpacity: 0.18,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Column(
            children: <Widget>[
              Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _bounceOffset,
              builder: (BuildContext context, Widget? child) {
                return Transform.translate(
                  offset: Offset(0, _bounceOffset.value),
                  child: child,
                );
              },
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.name,
    required this.storeName,
    required this.unitPriceLabel,
  });

  final String name;
  final String storeName;
  final String unitPriceLabel;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                name,
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.2,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              unitPriceLabel,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColors.brandPrimary,
                height: 1.2,
              ),
            ),
          ],
        ),
        if (storeName.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            storeName.trim(),
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.1,
          ),
    );
  }
}

class _StockNotice extends StatelessWidget {
  const _StockNotice({required this.text, required this.isWarning});

  final String text;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final Color color = isWarning ? AppColors.error : AppColors.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          isWarning ? Icons.error_outline_rounded : Icons.inventory_2_outlined,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
      ],
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.label,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = !enabled
        ? AppColors.homeMutedFill.withValues(alpha: 0.55)
        : selected
            ? AppColors.brandPrimary
            : AppColors.homeMutedFill;
    final Color fg = !enabled
        ? AppColors.textSecondary.withValues(alpha: 0.45)
        : selected
            ? Colors.white
            : AppColors.textPrimary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1.1,
                ),
          ),
        ),
      ),
    );
  }
}

class _TypeSelectionCard extends StatelessWidget {
  const _TypeSelectionCard({
    required this.group,
    required this.selected,
    required this.sizeIndex,
    required this.quantity,
    required this.unitPriceLabel,
    required this.onToggle,
    required this.onSizeSelected,
    required this.onQuantityChanged,
  });

  final ProductTypeGroup group;
  final bool selected;
  final int sizeIndex;
  final int quantity;
  final String unitPriceLabel;
  final VoidCallback onToggle;
  final ValueChanged<int> onSizeSelected;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.brandPrimary.withValues(alpha: 0.06)
          : AppColors.homeMutedFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 20,
                    color: selected
                        ? AppColors.brandPrimary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.type,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                  Text(
                    unitPriceLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              if (selected) ...<Widget>[
                if (group.hasSizeChoice) ...<Widget>[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List<Widget>.generate(group.sizes.length, (int i) {
                      return _OptionPill(
                        label: group.sizes[i].size,
                        selected: sizeIndex == i,
                        onTap: () => onSizeSelected(i),
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: _QtyStepper(
                    quantity: quantity,
                    onDecrement: quantity > 1
                        ? () => onQuantityChanged(quantity - 1)
                        : null,
                    onIncrement: () => onQuantityChanged(quantity + 1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({
    required this.name,
    required this.priceLabel,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String priceLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.brandPrimary.withValues(alpha: 0.06)
          : AppColors.homeMutedFill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: <Widget>[
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 18,
                color: selected
                    ? AppColors.brandPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              Text(
                priceLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.homeMutedFill,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _QtyButton(
            icon: Icons.remove_rounded,
            onTap: onDecrement,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$quantity',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          _QtyButton(
            icon: Icons.add_rounded,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 15,
            color: enabled
                ? AppColors.brandPrimary
                : AppColors.textSecondary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _AddToCartBar extends StatelessWidget {
  const _AddToCartBar({
    required this.totalLabel,
    required this.quantity,
    required this.onAdd,
    this.outOfStock = false,
  });

  final String totalLabel;
  final int quantity;
  final VoidCallback? onAdd;
  final bool outOfStock;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                ),
                const Spacer(),
                Text(
                  totalLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton.icon(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.homeMutedFill.withValues(alpha: 0.8),
                  disabledForegroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                label: Text(
                  outOfStock
                      ? 'Out of stock'
                      : onAdd == null
                          ? 'Select an item'
                          : 'Add to Cart (${quantity}x)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
