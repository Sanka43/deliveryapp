import 'package:flutter/material.dart';
import 'package:mnd_shop/features/products/presentation/widgets/vendor_products_ui.dart';

/// Numbered step title used inside the product Pricing card.
class PricingStepHeader extends StatelessWidget {
  const PricingStepHeader({
    super.key,
    required this.step,
    required this.title,
    this.subtitle,
  });

  final int step;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = VendorProductsTheme.accent(context);
    final Color primary = VendorProductsTheme.primaryText(context);
    final Color muted = VendorProductsTheme.mutedText(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: VendorProductsTheme.softAccentFill(context),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$step',
            style: theme.textTheme.labelLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Soft nested panel inside the Pricing card.
class PricingNestedPanel extends StatelessWidget {
  const PricingNestedPanel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = VendorProductsTheme.isDark(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : VendorProductsTheme.toggleTrack(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: VendorProductsTheme.inputBorder(context).withValues(
            alpha: dark ? 0.55 : 0.9,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: VendorProductsTheme.primaryText(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 10),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Equal-width chips for food price-by kind.
class PricingKindSelector extends StatelessWidget {
  const PricingKindSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const List<({String id, String label, IconData icon})> _kinds =
      <({String id, String label, IconData icon})>[
    (id: 'half', label: 'Half / Full', icon: Icons.pie_chart_outline_rounded),
    (id: 'size', label: 'Size', icon: Icons.straighten_rounded),
    (id: 'portion', label: 'Portion', icon: Icons.groups_2_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < _kinds.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _KindChip(
              label: _kinds[i].label,
              icon: _kinds[i].icon,
              selected: value == _kinds[i].id,
              onTap: () => onChanged(_kinds[i].id),
            ),
          ),
        ],
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = VendorProductsTheme.accent(context);
    final Color fg = selected
        ? VendorProductsTheme.chipSelectedFg(context)
        : VendorProductsTheme.primaryText(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? accent
                : VendorProductsTheme.cardSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent
                  : VendorProductsTheme.inputBorder(context),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: fg),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact label + LKR field row used throughout the Pricing card.
class PricingAmountRow extends StatelessWidget {
  const PricingAmountRow({
    super.key,
    required this.label,
    required this.controller,
    this.leadingWidth = 118,
    this.onRemove,
    this.hintText = '0',
  });

  final String label;
  final TextEditingController controller;
  final double leadingWidth;
  final VoidCallback? onRemove;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primary = VendorProductsTheme.primaryText(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: leadingWidth,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: primary,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: 'Rs. ',
                prefixStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: VendorProductsTheme.mutedText(context),
                  fontWeight: FontWeight.w700,
                ),
                hintText: hintText,
                isDense: true,
                filled: true,
                fillColor: VendorProductsTheme.inputFill(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// Type filter chips + custom type field.
class PricingTypeChipWrap extends StatelessWidget {
  const PricingTypeChipWrap({
    super.key,
    required this.presets,
    required this.customTypes,
    required this.selectedTypes,
    required this.onToggle,
  });

  final List<String> presets;
  final List<String> customTypes;
  final List<String> selectedTypes;
  final ValueChanged<String> onToggle;

  bool _isSelected(String type) => selectedTypes.any(
        (String t) => t.toLowerCase() == type.toLowerCase(),
      );

  @override
  Widget build(BuildContext context) {
    final Color accent = VendorProductsTheme.accent(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String preset in presets)
          FilterChip(
            label: Text(preset),
            selected: _isSelected(preset),
            showCheckmark: false,
            selectedColor: accent,
            checkmarkColor: VendorProductsTheme.chipSelectedFg(context),
            labelStyle: TextStyle(
              color: _isSelected(preset)
                  ? VendorProductsTheme.chipSelectedFg(context)
                  : VendorProductsTheme.primaryText(context),
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: _isSelected(preset)
                  ? accent
                  : VendorProductsTheme.inputBorder(context),
            ),
            onSelected: (_) => onToggle(preset),
          ),
        for (final String custom in customTypes)
          FilterChip(
            label: Text(custom),
            selected: _isSelected(custom),
            showCheckmark: false,
            selectedColor: accent,
            labelStyle: TextStyle(
              color: _isSelected(custom)
                  ? VendorProductsTheme.chipSelectedFg(context)
                  : VendorProductsTheme.primaryText(context),
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: _isSelected(custom)
                  ? accent
                  : VendorProductsTheme.inputBorder(context),
            ),
            onSelected: (_) => onToggle(custom),
          ),
      ],
    );
  }
}
