import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/products/data/vendor_product_repository.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';
import 'package:mnd_shop/features/products/presentation/pages/product_form_page.dart';
import 'package:mnd_shop/features/products/presentation/pages/product_list_page.dart';
import 'package:mnd_shop/features/products/presentation/widgets/vendor_products_ui.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_products_stream_provider.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_store_from_profile_provider.dart';

/// Vertical gap between catalog sections.
const double _kCatalogVerticalGap = 8;

/// Matches [VendorPageHeader] title metrics (Bebas 34 × height 1.05).
const double _kCatalogHeaderTitleSize = 34;

/// Search row height (underline field).
const double _kCatalogSearchRowHeight = 40;

/// Approximate fixed chrome below safe area (title + search row + metrics + gaps).
const double _kCatalogFixedHeaderBelowSafeArea = 196;

/// Products hub — premium mobile inventory UX (stats, search, cards, gestures).
class VendorCatalogHubPage extends ConsumerWidget {
  const VendorCatalogHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(vendorStoreFromProfileProvider);
    // Nested Scaffold inside IndexedStack often yields a zero-height body; use Material
    // so the catalogue always fills the tab and products actually paint.
    return Material(
      color: VendorProductsTheme.canvas(context),
      clipBehavior: Clip.none,
      child: const _VendorCatalogUnifiedBody(),
    );
  }
}

class _VendorCatalogUnifiedBody extends ConsumerStatefulWidget {
  const _VendorCatalogUnifiedBody();

  @override
  ConsumerState<_VendorCatalogUnifiedBody> createState() => _VendorCatalogUnifiedBodyState();
}

class _VendorCatalogUnifiedBodyState extends ConsumerState<_VendorCatalogUnifiedBody> {
  final Set<String> _busyIds = <String>{};
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _setStockDialog(VendorProduct p) async {
    final int? q = await showVendorStockDialog(
      context,
      productName: p.name,
      initialQty: p.stockQty,
    );
    if (!mounted) {
      return;
    }
    if (q == null) {
      return;
    }
    if (q < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a whole number ≥ 0')),
      );
      return;
    }
    await _runStockOp(p.id, () async {
      await ref.read(vendorProductRepositoryProvider).setProductStock(
            productId: p.id,
            quantity: q,
          );
    });
  }

  Future<void> _runStockOp(String productId, Future<void> Function() op) async {
    setState(() => _busyIds.add(productId));
    try {
      await op();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(productId));
      }
    }
  }

  void _openEdit(VendorProduct p) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductFormPage(product: p),
      ),
    );
  }

  void _openAddProduct() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ProductFormPage(product: null),
      ),
    );
  }

  List<VendorProduct> _applyQuerySortFilter(List<VendorProduct> raw) {
    final String q = _searchController.text.trim().toLowerCase();
    Iterable<VendorProduct> list = raw;
    if (q.isNotEmpty) {
      list = list.where(
        (VendorProduct p) =>
            p.name.toLowerCase().contains(q) ||
            p.lookupKey.contains(q) ||
            p.description.toLowerCase().contains(q),
      );
    }
    final List<VendorProduct> out = list.toList(growable: false);
    out.sort(
      (VendorProduct a, VendorProduct b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return out;
  }

  Future<void> _onRefresh() async {
    ref.invalidate(vendorProductsStreamProvider);
    await Future<void>.delayed(const Duration(milliseconds: 450));
  }

  Widget _catalogScrollBody({required Widget child}) {
    return _CatalogScrollBody(child: child);
  }

  Widget _productListTile(VendorProduct p, {required bool isLast}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 11),
      child: Dismissible(
        key: Key('product_${p.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.circular(kVendorCardRadius),
          ),
          child: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.onError),
        ),
        confirmDismiss: (DismissDirection dir) async {
          final bool? ok = await showVendorConfirmDialog(
            context,
            title: 'Delete product?',
            message: 'Remove "${p.name}" from the catalogue?',
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (ok != true) {
            return false;
          }
          try {
            await ref.read(vendorProductRepositoryProvider).deleteProduct(p);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted · ${p.name}')),
              );
            }
            return true;
          } on Exception catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Delete failed: $e')),
              );
            }
            return false;
          }
        },
        child: _ModernProductCard(
          product: p,
          busy: _busyIds.contains(p.id),
          onEdit: () => _openEdit(p),
          onSetQuantity: () {
            HapticFeedback.selectionClick();
            _setStockDialog(p);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(vendorStoreFromProfileProvider);
    final String catalogStoreId = ref.watch(vendorProductCatalogStoreIdProvider).trim();
    final AsyncValue<List<VendorProduct>> products = ref.watch(vendorProductsStreamProvider);
    final bool showAddProduct = vendorCatalogCanAddProducts(catalogStoreId);
    final double topInset = MediaQuery.paddingOf(context).top;

    if (catalogStoreId.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CatalogStaticHeader(
            topInset: topInset,
            searchController: _searchController,
            onSearchChanged: (_) => setState(() {}),
            showSearch: false,
            showAddProduct: false,
          ),
          Expanded(
            child: _catalogScrollBody(child: const _SignInRequiredPane()),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        products.when(
          data: (List<VendorProduct> list) {
            final int out = list.where((VendorProduct p) => p.stockQty == 0).length;
            final int low = list
                .where((VendorProduct p) => p.stockQty > 0 && p.stockQty <= vendorLowStockMax)
                .length;
            final int activeCount = list.where((VendorProduct p) => p.active).length;
            return _CatalogStaticHeader(
              topInset: topInset,
              metrics: VendorCatalogMetrics(
                total: list.length,
                outCount: out,
                lowCount: low,
                activeCount: activeCount,
              ),
              searchController: _searchController,
              onSearchChanged: (_) => setState(() {}),
              showAddProduct: showAddProduct,
              onAddProduct: _openAddProduct,
            );
          },
          loading: () => _CatalogStaticHeader(
            topInset: topInset,
            metrics: _CatalogMetricsSkeleton(),
            searchController: _searchController,
            onSearchChanged: (_) => setState(() {}),
            showAddProduct: showAddProduct,
            onAddProduct: _openAddProduct,
          ),
          error: (_, __) => _CatalogStaticHeader(
            topInset: topInset,
            searchController: _searchController,
            onSearchChanged: (_) => setState(() {}),
            showAddProduct: showAddProduct,
            onAddProduct: _openAddProduct,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            edgeOffset: topInset + _kCatalogFixedHeaderBelowSafeArea,
            onRefresh: _onRefresh,
            child: products.when(
              data: (List<VendorProduct> list) {
                if (list.isEmpty) {
                  return _catalogScrollBody(
                    child: const Column(
                      children: <Widget>[
                        Expanded(child: _EmptyCatalogIllustration()),
                      ],
                    ),
                  );
                }

                final int out = list.where((VendorProduct p) => p.stockQty == 0).length;
                final int low = list
                    .where((VendorProduct p) => p.stockQty > 0 && p.stockQty <= vendorLowStockMax)
                    .length;
                final List<VendorProduct> visible = _applyQuerySortFilter(list);

                if (visible.isEmpty) {
                  return _catalogScrollBody(
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          child: _NoSearchResults(
                            onClear: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    kVendorScreenPadding,
                    _kCatalogVerticalGap,
                    kVendorScreenPadding,
                    96,
                  ),
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  itemCount: visible.length + ((low > 0 || out > 0) ? 1 : 0),
                  itemBuilder: (BuildContext context, int index) {
                    int i = index;
                    if (low > 0 || out > 0) {
                      if (i == 0) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: _kCatalogVerticalGap * 2),
                          child: _InventoryAlertBanner(
                            lowCount: low,
                            outCount: out,
                            totalSkus: list.length,
                          ),
                        );
                      }
                      i -= 1;
                    }
                    final VendorProduct p = visible[i];
                    return _productListTile(p, isLast: i == visible.length - 1);
                  },
                );
              },
              loading: () => _catalogScrollBody(
                child: Column(
                  children: <Widget>[
                    const Expanded(child: _CatalogListSkeleton()),
                    const Padding(
                      padding: EdgeInsets.only(top: 24, bottom: 48),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(strokeWidth: 2.8),
                      ),
                    ),
                  ],
                ),
              ),
              error: (Object e, StackTrace _) => _catalogScrollBody(
                child: Column(
                  children: <Widget>[
                    Expanded(child: _CatalogErrorPane(message: '$e')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fixed top chrome: title → search + add → metrics (list scrolls below).
class _CatalogStaticHeader extends StatelessWidget {
  const _CatalogStaticHeader({
    required this.topInset,
    required this.searchController,
    required this.onSearchChanged,
    this.metrics,
    this.showSearch = true,
    this.showAddProduct = false,
    this.onAddProduct,
  });

  final double topInset;
  final Widget? metrics;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool showSearch;
  final bool showAddProduct;
  final VoidCallback? onAddProduct;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VendorProductsTheme.canvas(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              kVendorScreenPadding,
              topInset + 12,
              kVendorScreenPadding,
              showSearch ? 10 : _kCatalogVerticalGap,
            ),
            child: const _CatalogTitleRow(),
          ),
          if (showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kVendorScreenPadding,
                0,
                kVendorScreenPadding,
                _kCatalogVerticalGap,
              ),
              child: _CatalogSearchAddRow(
                searchController: searchController,
                onSearchChanged: onSearchChanged,
                showAddProduct: showAddProduct,
                onAddProduct: onAddProduct,
              ),
            ),
          if (metrics != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                kVendorScreenPadding,
                showSearch ? 0 : _kCatalogVerticalGap,
                kVendorScreenPadding,
                _kCatalogVerticalGap,
              ),
              child: metrics,
            ),
        ],
      ),
    );
  }
}

class _CatalogTitleRow extends StatelessWidget {
  const _CatalogTitleRow();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle titleStyle = GoogleFonts.bebasNeue(
      textStyle: theme.textTheme.headlineMedium,
      fontSize: _kCatalogHeaderTitleSize,
      letterSpacing: 1.0,
      height: 1.05,
      color: VendorProductsTheme.primaryText(context),
    ).copyWith(fontFamilyFallback: const <String>['Poppins']);

    return Text(
      'Products',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );
  }
}

/// Search field (expanded) + compact Add product CTA on one row.
class _CatalogSearchAddRow extends StatelessWidget {
  const _CatalogSearchAddRow({
    required this.searchController,
    required this.onSearchChanged,
    required this.showAddProduct,
    this.onAddProduct,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool showAddProduct;
  final VoidCallback? onAddProduct;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: _CatalogHeaderSearch(
            height: _kCatalogSearchRowHeight,
            controller: searchController,
            onChanged: onSearchChanged,
          ),
        ),
        if (showAddProduct && onAddProduct != null) ...<Widget>[
          const SizedBox(width: 10),
          _CatalogHeaderAddButton(onPressed: onAddProduct),
        ],
      ],
    );
  }
}

class _CatalogHeaderAddButton extends StatelessWidget {
  const _CatalogHeaderAddButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color accent = VendorProductsTheme.accent(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, _kCatalogSearchRowHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        'Add product',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.white,
              height: 1.1,
            ),
      ),
    );
  }
}

/// Pill search aligned to the catalog title row.
class _CatalogHeaderSearch extends StatefulWidget {
  const _CatalogHeaderSearch({
    required this.height,
    required this.controller,
    required this.onChanged,
  });

  final double height;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_CatalogHeaderSearch> createState() => _CatalogHeaderSearchState();
}

class _CatalogHeaderSearchState extends State<_CatalogHeaderSearch> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  void _onFocusChanged() => setState(() {});

  void _clear() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool focused = _focusNode.hasFocus;
    final bool hasText = widget.controller.text.isNotEmpty;
    final double h = widget.height;
    final Color primary = VendorProductsTheme.primaryText(context);
    final Color muted = VendorProductsTheme.mutedText(context);
    final Color accent = VendorProductsTheme.accent(context);
    final Color underlineIdle = VendorProductsTheme.searchUnderline(context);

    return SizedBox(
      height: h,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    onChanged: widget.onChanged,
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                      fontSize: 13.5,
                      letterSpacing: -0.1,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Search products',
                      hintStyle: theme.textTheme.labelLarge?.copyWith(
                        color: muted.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.only(bottom: 2),
                    ),
                  ),
                ),
                if (hasText)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _clear,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: muted.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: focused ? 2 : 1,
            decoration: BoxDecoration(
              color: focused ? accent : underlineIdle,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogScrollBody extends StatelessWidget {
  const _CatalogScrollBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double bodyHeight = constraints.maxHeight;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: bodyHeight, maxHeight: bodyHeight),
            child: child,
          ),
        );
      },
    );
  }
}

class _CatalogMetricsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Color base = VendorProductsTheme.isDark(context)
        ? Theme.of(context).colorScheme.surfaceContainerHigh
        : Color.lerp(
              AppColors.surfaceMuted,
              Theme.of(context).colorScheme.onSurface,
              0.06,
            ) ??
            AppColors.surfaceMuted;
    return SizedBox(
      height: 72,
      child: Row(
        children: List<Widget>.generate(
          4,
          (int i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(VendorPlainStatTile.radius),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogListSkeleton extends StatelessWidget {
  const _CatalogListSkeleton();

  @override
  Widget build(BuildContext context) {
    final Color base = VendorProductsTheme.isDark(context)
        ? Theme.of(context).colorScheme.surfaceContainerHigh
        : Color.lerp(
              AppColors.surfaceMuted,
              Theme.of(context).colorScheme.onSurface,
              0.06,
            ) ??
            AppColors.surfaceMuted;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        kVendorScreenPadding,
        _kCatalogVerticalGap,
        kVendorScreenPadding,
        24,
      ),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 5,
      itemBuilder: (BuildContext _, int i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VendorProductsTheme.cardSurface(context),
            borderRadius: BorderRadius.circular(kVendorCardRadius),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: SizedBox(
            height: 108,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SizedBox(width: 72, height: 72),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        DecoratedBox(
                          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
                          child: const SizedBox(height: 14, width: 140),
                        ),
                        const SizedBox(height: 10),
                        DecoratedBox(
                          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
                          child: const SizedBox(height: 12, width: 90),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryAlertBanner extends StatelessWidget {
  const _InventoryAlertBanner({
    required this.lowCount,
    required this.outCount,
    required this.totalSkus,
  });

  final int lowCount;
  final int outCount;
  final int totalSkus;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> parts = <String>[];
    if (outCount > 0) {
      parts.add('$outCount out of stock');
    }
    if (lowCount > 0) {
      parts.add('$lowCount low stock');
    }
    return Material(
      color: VendorProductsTheme.inventoryBannerFill(context),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.lightbulb_outline_rounded, color: AppColors.pendingAmber, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${parts.join(' · ')} · review ${totalSkus > 0 ? 'inventory' : 'items'} soon.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: VendorProductsTheme.primaryText(context),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kVendorScreenPadding + 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: VendorProductsTheme.accent(context).withValues(alpha: 0.75),
          ),
          const SizedBox(height: 14),
          const VendorSectionTitle('No matches'),
          const SizedBox(height: 8),
          Text(
            'Try another search or clear filters.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: VendorProductsTheme.mutedText(context)),
          ),
          const SizedBox(height: 18),
          VendorHeroFilledButton(
            label: 'Clear search',
            icon: Icons.clear_rounded,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _SignInRequiredPane extends StatelessWidget {
  const _SignInRequiredPane();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VendorProductsTheme.softAccentFill(context, lightAlpha: 0.12, darkAlpha: 0.2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 44,
                color: VendorProductsTheme.accent(context),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const VendorSectionTitle('Sign in to manage products'),
          const SizedBox(height: 10),
          Text(
            'Your catalogue and inventory controls will show here once your shop session is active.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: VendorProductsTheme.mutedText(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCatalogIllustration extends StatelessWidget {
  const _EmptyCatalogIllustration();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kVendorCardRadius),
              color: VendorProductsTheme.softAccentFill(context),
              border: Border.all(
                color: VendorProductsTheme.accent(context).withValues(alpha: 0.28),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 56,
                color: VendorProductsTheme.accent(context).withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const VendorSectionTitle('No products yet'),
          const SizedBox(height: 10),
          Text(
            'Tap Add product to create your first listing. Set price, photos, and stock anytime.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: VendorProductsTheme.mutedText(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogErrorPane extends StatelessWidget {
  const _CatalogErrorPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(kVendorCardRadius),
            border: Border.all(color: cs.error.withValues(alpha: 0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.cloud_off_outlined, color: cs.error, size: 36),
                const SizedBox(height: 12),
                const VendorSectionTitle('Could not load products'),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: VendorProductsTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Short description for product cards (~2 lines in the narrow text column).
const int _kProductCardSubtitleMax = 40;


String _categorySubtitle(VendorProduct p) {
  final String d = p.description.trim();
  if (d.isEmpty) {
    return 'General';
  }
  final int comma = d.indexOf(',');
  if (comma > 1 && comma <= 22) {
    return d.substring(0, comma).trim();
  }
  if (d.length <= _kProductCardSubtitleMax) {
    return d;
  }
  return '${d.substring(0, _kProductCardSubtitleMax - 1)}…';
}

class _ModernProductCard extends StatelessWidget {
  const _ModernProductCard({
    required this.product,
    required this.busy,
    required this.onEdit,
    required this.onSetQuantity,
  });

  final VendorProduct product;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onSetQuantity;

  static const double _kRadius = 16;
  static const double _kThumb = 68;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = VendorProductsTheme.isDark(context);
    final Color titleColor = VendorProductsTheme.primaryText(context);
    final Color mutedColor = VendorProductsTheme.mutedText(context);
    final Color accent = VendorProductsTheme.accent(context);

    final int q = product.stockQty;
    final bool isOut = q == 0;
    final bool isLow = q > 0 && q <= vendorLowStockMax;
    final Color cardBg = VendorProductsTheme.productCardBackground(
      context,
      isOut: isOut,
      isLow: isLow,
    );

    final bool hasVariants = product.sizeOptions.length > 1;
    final String priceText = product.priceLkr.toDouble().toStringAsFixed(2);

    final Color? cardBorder = VendorProductsTheme.productCardBorder(
      context,
      isOut: isOut,
      isLow: isLow,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadius),
        boxShadow: VendorProductsTheme.cardShadow(context),
        border: cardBorder != null ? Border.all(color: cardBorder) : null,
      ),
      child: Material(
        color: cardBg,
        elevation: 0,
        borderRadius: BorderRadius.circular(_kRadius),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              VendorProductThumb(
                url: product.imageUrl,
                size: _kThumb,
                borderRadius: 12,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onEdit,
                          borderRadius: BorderRadius.circular(10),
                          splashColor: accent.withValues(alpha: 0.08),
                          highlightColor: accent.withValues(alpha: 0.04),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  product.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    height: 1.15,
                                    color: titleColor,
                                    fontSize: 15.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _categorySubtitle(product),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: mutedColor,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!product.active) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: mutedColor.withValues(alpha: isDark ? 0.2 : 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Offline',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: mutedColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 9.5,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        if (hasVariants)
                          Text(
                            'From',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: mutedColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              height: 1,
                            ),
                          ),
                        Text(
                          'Rs. $priceText',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: titleColor,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.45,
                            height: 1.05,
                            fontSize: 16,
                            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ProductStockButton(
                          stockQty: q,
                          busy: busy,
                          onPressed: onSetQuantity,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductStockButton extends StatefulWidget {
  const _ProductStockButton({
    required this.stockQty,
    required this.busy,
    required this.onPressed,
  });

  final int stockQty;
  final bool busy;
  final VoidCallback onPressed;

  @override
  State<_ProductStockButton> createState() => _ProductStockButtonState();
}

class _ProductStockButtonState extends State<_ProductStockButton> {
  bool _pressed = false;

  Color _buttonColor(BuildContext context) {
    final Color accent = VendorProductsTheme.accent(context);
    final bool isDark = VendorProductsTheme.isDark(context);
    if (widget.busy) {
      return accent.withValues(alpha: isDark ? 0.45 : 0.55);
    }
    if (_pressed) {
      return Color.lerp(accent, Colors.black, isDark ? 0.18 : 0.14) ?? accent;
    }
    return accent;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = VendorProductsTheme.isDark(context);
    final Color accent = VendorProductsTheme.accent(context);
    final Color bg = _buttonColor(context);
    const Color fg = Colors.white;

    final String label = widget.busy
        ? 'Updating…'
        : 'Stock · ${widget.stockQty}';

    return AnimatedScale(
      scale: _pressed && !widget.busy ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: InkWell(
          onTap: widget.busy
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  widget.onPressed();
                },
          onHighlightChanged: widget.busy ? null : (bool v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withValues(alpha: 0.22),
          highlightColor: Colors.white.withValues(alpha: 0.12),
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: widget.busy
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.45 : 0.38),
                        blurRadius: _pressed ? 6 : 14,
                        offset: Offset(0, _pressed ? 2 : 5),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                        blurRadius: _pressed ? 2 : 6,
                        offset: Offset(0, _pressed ? 1 : 2),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (widget.busy) ...<Widget>[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: -0.05,
                      height: 1.1,
                      fontFeatures: widget.busy
                          ? null
                          : const <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
