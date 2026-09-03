import 'package:flutter/material.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_item_variant_chip.dart';

String _vTxt(
  BuildContext context, {
  required String en,
  required String si,
  String? ta,
}) {
  final String languageCode = Localizations.localeOf(context).languageCode;
  if (languageCode == 'si') return si;
  if (languageCode == 'ta') return ta ?? vendorTamilFallback(en);
  return en;
}

/// Per-item order list: quantity, name, size, and a veg/non-veg type badge
/// (parsed from the product form's `{Type} · {Size}` combo convention).
/// Pass [maxRows] to cap the list with a "+N more" line (e.g. dashboard
/// previews); leave it null to show every item (e.g. the full detail page).
///
/// Set [emphasizeVariants] on screens the shop reads while preparing an order
/// (the detail page) to match the new-order popup: the size becomes a tinted
/// chip instead of muted text, and add-ons are listed as amber chips. Dense
/// previews leave it off so cards stay compact.
class VendorOrderItemsList extends StatelessWidget {
  const VendorOrderItemsList({
    super.key,
    required this.items,
    required this.primaryText,
    required this.mutedText,
    this.maxRows,
    this.emphasizeVariants = false,
  });

  final List<VendorOrderLineItem> items;
  final Color primaryText;
  final Color mutedText;
  final int? maxRows;
  final bool emphasizeVariants;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final List<VendorOrderLineItem> visible =
        maxRows == null ? items : items.take(maxRows!).toList();
    final int extra = items.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < visible.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: emphasizeVariants ? 12 : 8),
          _VendorOrderItemRow(
            item: visible[i],
            primaryText: primaryText,
            mutedText: mutedText,
            emphasizeVariants: emphasizeVariants,
          ),
        ],
        if (extra > 0) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            _vTxt(context, en: '+$extra more', si: 'තවත් $extra'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _VendorOrderItemRow extends StatelessWidget {
  const _VendorOrderItemRow({
    required this.item,
    required this.primaryText,
    required this.mutedText,
    this.emphasizeVariants = false,
  });

  final VendorOrderLineItem item;
  final Color primaryText;
  final Color mutedText;
  final bool emphasizeVariants;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ({String? type, String size}) typeAndSize = item.typeAndSize;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${item.quantity}×',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: primaryText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (typeAndSize.type != null ||
                  typeAndSize.size.isNotEmpty ||
                  (emphasizeVariants && item.extras.isNotEmpty)) ...<Widget>[
                SizedBox(height: emphasizeVariants ? 6 : 3),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: emphasizeVariants ? 6 : 4,
                  children: <Widget>[
                    if (typeAndSize.type != null) _FoodTypeBadge(type: typeAndSize.type!),
                    if (typeAndSize.size.isNotEmpty)
                      if (emphasizeVariants)
                        VendorItemVariantChip.variant(text: typeAndSize.size)
                      else
                        Text(
                          typeAndSize.size,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    if (emphasizeVariants)
                      for (final String extra in item.extras)
                        VendorItemVariantChip.extra(text: extra),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Small colored pill for a food type (green = Veg, red = meat/other).
class _FoodTypeBadge extends StatelessWidget {
  const _FoodTypeBadge({required this.type});

  final String type;

  bool get _isVeg => type.trim().toLowerCase() == 'veg';

  @override
  Widget build(BuildContext context) {
    final Color color = _isVeg ? AppColors.openGreen : AppColors.orderRejectRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        type,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
      ),
    );
  }
}
