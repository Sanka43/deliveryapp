import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/dashboard/presentation/widgets/vendor_dashboard_ui.dart';
import 'package:mnd_shop/features/products/data/vendor_product_repository.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';
import 'package:mnd_shop/features/products/presentation/pages/product_list_page.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_products_stream_provider.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

enum _InventoryFilter { all, low, out, offline }

class VendorInventoryPage extends ConsumerStatefulWidget {
  const VendorInventoryPage({super.key});

  @override
  ConsumerState<VendorInventoryPage> createState() =>
      _VendorInventoryPageState();
}

class _VendorInventoryPageState extends ConsumerState<VendorInventoryPage> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Set<String> _busyIds = <String>{};
  _InventoryFilter _filter = _InventoryFilter.all;
  bool _bulkBusy = false;

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(VendorProduct product) {
    final TextEditingController controller = _controllers.putIfAbsent(
      product.id,
      () => TextEditingController(text: '${product.stockQty}'),
    );
    if (!_busyIds.contains(product.id) &&
        controller.text != '${product.stockQty}' &&
        controller.selection.baseOffset < 0) {
      controller.text = '${product.stockQty}';
    }
    return controller;
  }

  List<VendorProduct> _filtered(List<VendorProduct> products) {
    return switch (_filter) {
      _InventoryFilter.all => products,
      _InventoryFilter.low =>
        products
            .where(
              (VendorProduct p) =>
                  p.manageStock &&
                  p.stockQty > 0 &&
                  p.stockQty <= vendorLowStockMax,
            )
            .toList(growable: false),
      _InventoryFilter.out =>
        products
            .where(
              (VendorProduct p) => p.manageStock && p.stockQty == 0,
            )
            .toList(growable: false),
      _InventoryFilter.offline =>
        products.where((VendorProduct p) => !p.active).toList(growable: false),
    };
  }

  Future<void> _setStock(VendorProduct product, int quantity) async {
    setState(() => _busyIds.add(product.id));
    try {
      await ref
          .read(vendorProductRepositoryProvider)
          .setProductStock(
            productId: product.id,
            quantity: quantity,
            reason: 'inventory_page_set',
          );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(product.id));
      }
    }
  }

  Future<void> _saveVisible(List<VendorProduct> products) async {
    final Map<String, int> updates = <String, int>{};
    for (final VendorProduct product in products) {
      final int? qty = int.tryParse(_controllerFor(product).text.trim());
      if (qty != null && qty != product.stockQty) {
        updates[product.id] = qty;
      }
    }
    if (updates.isEmpty) {
      _snack('No stock changes to save.');
      return;
    }
    setState(() => _bulkBusy = true);
    try {
      await ref
          .read(vendorProductRepositoryProvider)
          .setManyProductStock(
            quantitiesByProductId: updates,
            reason: 'inventory_bulk_set',
          );
      _snack(
        'Saved ${updates.length} stock update${updates.length == 1 ? '' : 's'}.',
      );
    } finally {
      if (mounted) {
        setState(() => _bulkBusy = false);
      }
    }
  }

  Future<void> _autoHideOutOfStock() async {
    final String storeId = ref.read(vendorProductCatalogStoreIdProvider).trim();
    if (storeId.isEmpty) {
      _snack('Store session is not ready.', error: true);
      return;
    }
    setState(() => _bulkBusy = true);
    try {
      await ref
          .read(vendorProductRepositoryProvider)
          .autoHideOutOfStockProducts(storeId);
      _snack('Out-of-stock products hidden from customers.');
    } finally {
      if (mounted) {
        setState(() => _bulkBusy = false);
      }
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<VendorProduct>> productsAsync = ref.watch(
      vendorProductsStreamProvider,
    );
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final double gutter = vendorResponsiveHorizontalPadding(context);

    return Scaffold(
      backgroundColor: VendorDashboardTheme.canvas(context),
      body: SafeArea(
        child: productsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (Object e, StackTrace _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load inventory.\n${userFacingError(e, fallback: 'Please check your connection and try again.')}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: VendorDashboardTheme.mutedText(context),
                ),
              ),
            ),
          ),
          data: (List<VendorProduct> products) {
            final int low = products
                .where(
                  (VendorProduct p) =>
                      p.manageStock &&
                      p.stockQty > 0 &&
                      p.stockQty <= vendorLowStockMax,
                )
                .length;
            final int out = products
                .where(
                  (VendorProduct p) => p.manageStock && p.stockQty == 0,
                )
                .length;
            final int offline = products
                .where((VendorProduct p) => !p.active)
                .length;
            final List<VendorProduct> visible = _filtered(products);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 2, gutter, 10),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 36,
                          child: IconButton(
                            tooltip: MaterialLocalizations.of(context)
                                .backButtonTooltip,
                            onPressed: () =>
                                Navigator.of(context).maybePop(),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            alignment: Alignment.centerLeft,
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              size: 24,
                              color: theme.brightness == Brightness.dark
                                  ? cs.onSurface
                                  : AppColors.textCharcoal,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: const Alignment(-1, -0.08),
                            child: Text(
                              'Inventory',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.bebasNeue(
                                textStyle: theme.textTheme.headlineMedium,
                                fontSize: 34,
                                letterSpacing: 1.0,
                                height: 1.0,
                                color: theme.brightness == Brightness.dark
                                    ? cs.onSurface
                                    : AppColors.textCharcoal,
                              ).copyWith(
                                fontFamilyFallback: const <String>['Poppins'],
                              ),
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Hide out-of-stock products',
                          onPressed: _bulkBusy ? null : _autoHideOutOfStock,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.visibility_off_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
                  child: _FilterBar(
                    filter: _filter,
                    allCount: products.length,
                    lowCount: low,
                    outCount: out,
                    hiddenCount: offline,
                    onChanged: (_InventoryFilter value) {
                      setState(() => _filter = value);
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
                  child: _SummaryBar(
                    low: low,
                    out: out,
                    busy: _bulkBusy,
                    canSave: visible.isNotEmpty,
                    onSave: () => _saveVisible(visible),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const _InventoryEmptyState()
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 28),
                          itemCount: visible.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final VendorProduct product = visible[index];
                            return _InventoryProductTile(
                              product: product,
                              controller: _controllerFor(product),
                              busy: _busyIds.contains(product.id),
                              onMinus: () => _setStock(
                                product,
                                (product.stockQty - 1).clamp(0, 9999999),
                              ),
                              onPlus: () =>
                                  _setStock(product, product.stockQty + 1),
                              onSubmit: () {
                                final int? qty = int.tryParse(
                                  _controllerFor(product).text.trim(),
                                );
                                if (qty == null) {
                                  _snack('Enter a whole number.', error: true);
                                  return;
                                }
                                _setStock(product, qty);
                              },
                              onHistory: () => showModalBottomSheet<void>(
                                context: context,
                                showDragHandle: true,
                                backgroundColor:
                                    VendorDashboardTheme.cardSurface(context),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                ),
                                builder: (_) =>
                                    _StockHistorySheet(product: product),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.allCount,
    required this.lowCount,
    required this.outCount,
    required this.hiddenCount,
    required this.onChanged,
  });

  final _InventoryFilter filter;
  final int allCount;
  final int lowCount;
  final int outCount;
  final int hiddenCount;
  final ValueChanged<_InventoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<(_InventoryFilter, String, int)> items =
        <(_InventoryFilter, String, int)>[
      (_InventoryFilter.all, 'All', allCount),
      (_InventoryFilter.low, 'Low', lowCount),
      (_InventoryFilter.out, 'Out', outCount),
      (_InventoryFilter.offline, 'Hidden', hiddenCount),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.itemsBoxFill(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
      ),
      child: Row(
        children: <Widget>[
          for (final (_InventoryFilter, String, int) item in items)
            Expanded(
              child: _FilterPill(
                label: item.$2,
                count: item.$3,
                selected: filter == item.$1,
                onTap: () => onChanged(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected
            ? VendorDashboardTheme.cardSurface(context)
            : Colors.transparent,
        elevation: selected ? 1.5 : 0,
        shadowColor: cs.shadow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? VendorDashboardTheme.primaryText(context)
                        : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.vendorHeroBlue.withValues(alpha: 0.12)
                        : VendorDashboardTheme.itemsBoxFill(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.vendorHeroBlue
                          : VendorDashboardTheme.mutedText(context),
                    ),
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

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.low,
    required this.out,
    required this.busy,
    required this.canSave,
    required this.onSave,
  });

  final int low;
  final int out;
  final bool busy;
  final bool canSave;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Stock health',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: VendorDashboardTheme.mutedText(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$low low · $out out',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: VendorDashboardTheme.primaryText(context),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: busy || !canSave ? null : onSave,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.vendorHeroBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.vendorHeroBlue.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _InventoryProductTile extends StatelessWidget {
  const _InventoryProductTile({
    required this.product,
    required this.controller,
    required this.busy,
    required this.onMinus,
    required this.onPlus,
    required this.onSubmit,
    required this.onHistory,
  });

  final VendorProduct product;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onSubmit;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool out = product.manageStock && product.stockQty == 0;
    final bool low = product.manageStock &&
        product.stockQty > 0 &&
        product.stockQty <= vendorLowStockMax;
    final Color statusColor = !product.manageStock
        ? VendorDashboardTheme.mutedText(context)
        : out
            ? AppColors.orderRejectRed
            : low
                ? AppColors.pendingAmber
                : AppColors.openGreen;
    final String statusLabel = !product.manageStock
        ? 'Not tracked'
        : out
            ? 'Out of stock'
            : low
                ? 'Low stock'
                : 'In stock';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              VendorProductThumb(
                url: product.imageUrl,
                size: 56,
                borderRadius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: VendorDashboardTheme.primaryText(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _StatusPill(
                          label: statusLabel,
                          color: statusColor,
                        ),
                        if (!product.active)
                          _StatusPill(
                            label: 'Hidden',
                            color: VendorDashboardTheme.mutedText(context),
                            soft: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'History',
                onPressed: onHistory,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  foregroundColor: VendorDashboardTheme.mutedText(context),
                  backgroundColor: VendorDashboardTheme.itemsBoxFill(context),
                ),
                icon: const Icon(Icons.history_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: VendorDashboardTheme.itemsBoxFill(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: VendorDashboardTheme.sectionBorder(context),
              ),
            ),
            child: Row(
              children: <Widget>[
                _QtyButton(
                  tooltip: 'Decrease',
                  icon: Icons.remove_rounded,
                  onPressed: busy ? null : onMinus,
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
                _QtyButton(
                  tooltip: 'Increase',
                  icon: Icons.add_rounded,
                  onPressed: busy ? null : onPlus,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.soft = false,
  });

  final String label;
  final Color color;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: soft ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: AppColors.vendorHeroBlue,
        backgroundColor: VendorDashboardTheme.cardSurface(context),
        disabledForegroundColor:
            VendorDashboardTheme.mutedText(context).withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: VendorDashboardTheme.sectionBorder(context),
          ),
        ),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _StockHistorySheet extends ConsumerWidget {
  const _StockHistorySheet({required this.product});

  final VendorProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> history = ref.watch(
      StreamProvider<List<Map<String, dynamic>>>(
        (Ref ref) => ref
            .watch(vendorProductRepositoryProvider)
            .watchStockMovements(product.id),
      ),
    );

    return SizedBox(
      height: 380,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Stock history',
              style: theme.textTheme.labelMedium?.copyWith(
                color: VendorDashboardTheme.mutedText(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: VendorDashboardTheme.primaryText(context),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: history.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (Object e, StackTrace _) => Center(
                  child: Text(
                    userFacingError(
                      e,
                      fallback: 'Could not load stock history.',
                    ),
                  ),
                ),
                data: (List<Map<String, dynamic>> rows) {
                  if (rows.isEmpty) {
                    return Center(
                      child: Text(
                        'No stock history yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: VendorDashboardTheme.mutedText(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final Map<String, dynamic> row = rows[index];
                      final int previous =
                          (row['previousQty'] as num?)?.round() ?? 0;
                      final int next = (row['nextQty'] as num?)?.round() ?? 0;
                      final int delta = (row['delta'] as num?)?.round() ?? 0;
                      final Timestamp? createdAt =
                          row['createdAt'] as Timestamp?;
                      final DateTime? time = createdAt?.toDate();
                      final Color deltaColor = delta >= 0
                          ? AppColors.openGreen
                          : AppColors.orderRejectRed;

                      return Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: VendorDashboardTheme.itemsBoxFill(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: VendorDashboardTheme.sectionBorder(context),
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: deltaColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${delta >= 0 ? '+' : ''}$delta',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: deltaColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '$previous → $next',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${row['reason'] ?? 'stock_update'}'
                                    '${time == null ? '' : ' · ${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: VendorDashboardTheme.mutedText(
                                        context,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.vendorHeroBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 34,
                color: AppColors.vendorHeroBlue,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No items in this view',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: VendorDashboardTheme.primaryText(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Switch filters or add products to manage stock here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: VendorDashboardTheme.mutedText(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
