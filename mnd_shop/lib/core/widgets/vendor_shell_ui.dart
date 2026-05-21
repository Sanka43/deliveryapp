import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';

/// Horizontal gutter aligned with vendor Home tab.
const double kVendorScreenPadding = 20;

/// Primary section / product card corner radius.
const double kVendorCardRadius = 24;

/// Stat mini-card corner radius.
const double kVendorStatCardRadius = 18;

/// Tighter stat tiles inside the home hero gradient card.
const double kVendorHeroStatCardRadius = 16;

/// Layout density for [VendorStatMiniCard].
enum VendorStatMiniCardDensity { standard, hero }

/// Form field corner radius (matches [AppTheme] inputs).
const double kVendorFormFieldRadius = 14;

/// Dialog corner radius.
const double kVendorDialogRadius = 22;

/// Section heading — Poppins w800 on charcoal.
class VendorSectionTitle extends StatelessWidget {
  const VendorSectionTitle(this.title, {super.key, this.color});

  final String title;

  /// When null, uses [AppColors.textCharcoal] (light-mode default).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.45,
        color: color ?? (dark ? theme.colorScheme.onSurface : AppColors.textCharcoal),
        height: 1.2,
      ),
    );
  }
}

/// Catalog / dashboard stat tile with gradient fill.
class VendorStatMiniCard extends StatelessWidget {
  const VendorStatMiniCard({
    super.key,
    required this.label,
    required this.value,
    required this.gradient,
    this.labelColor,
    this.valueColor,
    this.borderColor,
    this.valueCompact = false,
    this.density = VendorStatMiniCardDensity.standard,
    this.hint,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String value;
  final List<Color> gradient;
  final Color? labelColor;
  final Color? valueColor;
  final Color? borderColor;
  final bool valueCompact;
  final VendorStatMiniCardDensity density;
  final String? hint;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color resolvedLabel = labelColor ?? AppColors.textMuted;
    final Color resolvedValue = valueColor ?? AppColors.textCharcoal;
    final Color accent = valueColor ?? AppColors.textCharcoal;
    final Color resolvedBorder = selected
        ? accent.withValues(alpha: 0.85)
        : (borderColor ?? cs.outlineVariant.withValues(alpha: 0.18));
    final double borderWidth = selected ? 2.0 : 1.0;
    final bool hero = density == VendorStatMiniCardDensity.hero;
    final double baseTitleSize = theme.textTheme.titleLarge?.fontSize ?? 22;
    final double valueFontSize = hero
        ? 16.5
        : baseTitleSize * (valueCompact ? 0.88 : 1.02);

    final TextStyle valueStyle = (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
      fontWeight: hero ? FontWeight.w800 : FontWeight.w900,
      letterSpacing: hero ? -0.35 : -0.5,
      height: 1.08,
      color: resolvedValue,
      fontSize: valueFontSize,
    );

    final Widget valueChild = SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          value,
          maxLines: 1,
          softWrap: false,
          style: valueStyle,
        ),
      ),
    );

    final double cardRadius = hero ? kVendorHeroStatCardRadius : kVendorStatCardRadius;
    final EdgeInsets cardPadding = hero
        ? const EdgeInsets.fromLTRB(12, 9, 12, 9)
        : const EdgeInsets.fromLTRB(10, 12, 10, 12);

    final Widget card = Container(
      padding: cardPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: selected
              ? <Color>[
                  accent.withValues(alpha: 0.14),
                  gradient.last,
                ]
              : gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: resolvedBorder, width: borderWidth),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: selected
                ? accent.withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: hero ? 0.035 : 0.045),
            blurRadius: selected ? 14 : (hero ? 10 : 12),
            offset: Offset(0, hero ? 4 : 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: resolvedLabel,
              fontWeight: FontWeight.w600,
              letterSpacing: hero ? 0.35 : 0.5,
              fontSize: hero ? 9 : 10,
              height: 1.15,
            ),
          ),
          SizedBox(height: hero ? 5 : 8),
          valueChild,
          if (hint != null && hint!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: resolvedLabel,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                height: 1.15,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: card,
      ),
    );
  }
}

/// Compact chip used on hero cards (dashboard).
class VendorHeroInsightChip extends StatelessWidget {
  const VendorHeroInsightChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.fillColor,
    this.borderColor,
    this.iconColor,
    this.labelColor,
    this.valueColor,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? fillColor;
  final Color? borderColor;
  final Color? iconColor;
  final Color? labelColor;
  final Color? valueColor;

  /// When true, chip stretches to parent width (use inside [Expanded]).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color bg = fillColor ?? cs.surface.withValues(alpha: 0.55);
    final Color border = borderColor ?? cs.outlineVariant.withValues(alpha: 0.35);
    final Color iconTint = iconColor ?? cs.primary;
    final Color labelTint = labelColor ?? AppColors.textMuted;
    final Color valueTint = valueColor ?? cs.onSurface;
    return Container(
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 17, color: iconTint),
          const SizedBox(width: 9),
          if (expand)
            Expanded(child: _HeroChipTextColumn(
              theme: theme,
              label: label,
              value: value,
              labelTint: labelTint,
              valueTint: valueTint,
            ))
          else
            _HeroChipTextColumn(
              theme: theme,
              label: label,
              value: value,
              labelTint: labelTint,
              valueTint: valueTint,
            ),
        ],
      ),
    );
  }
}

class _HeroChipTextColumn extends StatelessWidget {
  const _HeroChipTextColumn({
    required this.theme,
    required this.label,
    required this.value,
    required this.labelTint,
    required this.valueTint,
  });

  final ThemeData theme;
  final String label;
  final String value;
  final Color labelTint;
  final Color valueTint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: labelTint,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.42,
            fontSize: 9.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.15,
            height: 1.1,
            color: valueTint,
          ),
        ),
      ],
    );
  }
}

/// Bebas display title + optional eyebrow and subtitle (Product tab, etc.).
class VendorPageHeader extends StatelessWidget {
  const VendorPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.titleFontSize = 34,
    this.titleColor,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double titleFontSize;

  /// When null, uses [AppColors.textCharcoal] (light-mode default).
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (eyebrow != null && eyebrow!.isNotEmpty) ...<Widget>[
                Text(
                  eyebrow!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.12,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.bebasNeue(
                  textStyle: theme.textTheme.headlineMedium,
                  fontSize: titleFontSize,
                  letterSpacing: 1.0,
                  height: 1.05,
                  color: titleColor ?? AppColors.textCharcoal,
                ).copyWith(fontFamilyFallback: const <String>['Poppins']),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textMuted,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Truncates shop name for the dashboard header (grapheme-safe).
String vendorShortShopNameForHeader(String name, {int maxChars = 23}) {
  if (name.isEmpty) {
    return 'Your shop';
  }
  final Characters ch = name.characters;
  if (ch.length <= maxChars) {
    return name;
  }
  return '${ch.take(maxChars).string}\u2026';
}

/// Home tab header: greeting + Bebas shop name + notifications.
class VendorDashboardHeader extends StatelessWidget {
  const VendorDashboardHeader({
    super.key,
    required this.greeting,
    required this.shopName,
    required this.unreadCount,
    required this.onNotificationTap,
  });

  final String greeting;
  final String shopName;
  final int unreadCount;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final ColorScheme cs = theme.colorScheme;
    final Color greetingColor = dark ? cs.onSurfaceVariant : AppColors.textMuted;
    final Color titleColor = dark ? cs.onSurface : AppColors.textCharcoal;
    final Color iconColor = dark ? cs.onSurface : AppColors.textCharcoal;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                greeting,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: greetingColor,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.12,
                  fontSize: 11.5,
                ),
              ),
              Text(
                vendorShortShopNameForHeader(shopName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.bebasNeue(
                  textStyle: theme.textTheme.headlineSmall,
                  fontSize: 30,
                  letterSpacing: 1.1,
                  height: 1.05,
                  color: titleColor,
                ).copyWith(fontFamilyFallback: const <String>['Poppins']),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onNotificationTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text(
                  '${unreadCount > 9 ? '9+' : unreadCount}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
                backgroundColor: AppColors.orderRejectRed,
                child: Icon(
                  Icons.notifications_rounded,
                  color: iconColor,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// White stat tile — bold value on top, uppercase label below (order pipeline style).
class VendorPlainStatTile extends StatelessWidget {
  const VendorPlainStatTile({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  static const double radius = 14;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color textColor = dark ? theme.colorScheme.onSurface : AppColors.textCharcoal;
    final Color bg = dark ? const Color(0xFF1E2433) : Colors.white;
    final List<BoxShadow> shadows = dark
        ? <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
          ]
        : <BoxShadow>[
            BoxShadow(
              color: AppColors.textCharcoal.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 3),
              spreadRadius: -1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ];

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
              color: textColor,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.35,
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Four-tile inventory metrics row (Total / Out / Low / Live).
class VendorCatalogMetrics extends StatelessWidget {
  const VendorCatalogMetrics({
    super.key,
    required this.total,
    required this.outCount,
    required this.lowCount,
    required this.activeCount,
  });

  final int total;
  final int outCount;
  final int lowCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: VendorPlainStatTile(label: 'Total', value: '$total'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: VendorPlainStatTile(label: 'Out', value: '$outCount'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: VendorPlainStatTile(label: 'Low', value: '$lowCount'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: VendorPlainStatTile(label: 'Live', value: '$activeCount'),
        ),
      ],
    );
  }
}

/// Order list filter driven by pipeline metric tiles.
enum VendorOrderPipelineFilter {
  newOrders,
  kitchen,
  ready,
  active,
}

/// Four-tile order pipeline snapshot (New / Kitchen / Ready / Active).
class VendorOrderPipelineMetrics extends StatelessWidget {
  const VendorOrderPipelineMetrics({
    super.key,
    required this.incomingCount,
    required this.kitchenCount,
    required this.readyCount,
    required this.activeCount,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final int incomingCount;
  final int kitchenCount;
  final int readyCount;
  final int activeCount;
  final VendorOrderPipelineFilter selectedFilter;
  final ValueChanged<VendorOrderPipelineFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> baseGradient =
        dark ? AppColors.statTileGradientDark : AppColors.statTileGradientLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: VendorStatMiniCard(
            label: 'New',
            value: '$incomingCount',
            gradient: baseGradient,
            hint: incomingCount == 0 ? '—' : 'incoming',
            valueColor: incomingCount > 0 ? AppColors.vendorHeroBlue : AppColors.textCharcoal,
            valueCompact: true,
            selected: selectedFilter == VendorOrderPipelineFilter.newOrders,
            onTap: () => onFilterSelected(VendorOrderPipelineFilter.newOrders),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: VendorStatMiniCard(
            label: 'Kitchen',
            value: '$kitchenCount',
            gradient: baseGradient,
            hint: kitchenCount == 0 ? '—' : 'prepping',
            valueColor: kitchenCount > 0 ? AppColors.pendingAmber : AppColors.textCharcoal,
            valueCompact: true,
            selected: selectedFilter == VendorOrderPipelineFilter.kitchen,
            onTap: () => onFilterSelected(VendorOrderPipelineFilter.kitchen),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: VendorStatMiniCard(
            label: 'Ready',
            value: '$readyCount',
            gradient: baseGradient,
            hint: readyCount == 0 ? '—' : 'pickup',
            valueColor: readyCount > 0 ? AppColors.openGreen : AppColors.textCharcoal,
            valueCompact: true,
            selected: selectedFilter == VendorOrderPipelineFilter.ready,
            onTap: () => onFilterSelected(VendorOrderPipelineFilter.ready),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: VendorStatMiniCard(
            label: 'Active',
            value: '$activeCount',
            gradient: baseGradient,
            hint: activeCount == 0 ? '—' : 'open',
            valueColor: activeCount > 0 ? AppColors.textCharcoal : AppColors.textMuted,
            valueCompact: true,
            selected: selectedFilter == VendorOrderPipelineFilter.active,
            onTap: () => onFilterSelected(VendorOrderPipelineFilter.active),
          ),
        ),
      ],
    );
  }
}

/// Hero-style primary CTA (Add product, Save, etc.).
class VendorHeroFilledButton extends StatelessWidget {
  const VendorHeroFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final Widget child = FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.white,
            ),
      ),
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.vendorHeroBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        minimumSize: expanded ? const Size(double.infinity, 48) : Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
    if (expanded) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}

/// Confirm dialog with vendor chrome.
Future<bool?> showVendorConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      final ThemeData t = Theme.of(ctx);
      final ColorScheme cs = t.colorScheme;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kVendorDialogRadius)),
        title: Text(
          title,
          style: t.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textCharcoal,
          ),
        ),
        content: Text(
          message,
          style: t.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted, height: 1.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: destructive ? cs.error : AppColors.vendorHeroBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}

/// Stock quantity dialog with vendor chrome.
Future<int?> showVendorStockDialog(
  BuildContext context, {
  required String productName,
  required int initialQty,
}) {
  return showDialog<int>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (BuildContext ctx) => _VendorStockDialog(
      productName: productName,
      initialQty: initialQty,
    ),
  );
}

class _VendorStockDialog extends StatefulWidget {
  const _VendorStockDialog({
    required this.productName,
    required this.initialQty,
  });

  final String productName;
  final int initialQty;

  @override
  State<_VendorStockDialog> createState() => _VendorStockDialogState();
}

class _VendorStockDialogState extends State<_VendorStockDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialQty}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(context, int.tryParse(_controller.text.trim()));
  }

  void _adjust(int delta) {
    final int current = int.tryParse(_controller.text.trim()) ?? 0;
    final int next = (current + delta).clamp(0, 999999);
    _controller.text = '$next';
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color titleColor = isDark ? theme.colorScheme.onSurface : AppColors.textCharcoal;
    final Color mutedColor = isDark ? theme.colorScheme.onSurfaceVariant : AppColors.textMuted;
    final Color fieldFill = isDark ? theme.colorScheme.surfaceContainerHigh : AppColors.surfaceMuted.withValues(alpha: 0.55);
    final Color accent = isDark ? const Color(0xFF8B7EFF) : AppColors.vendorHeroBlue;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2030) : Colors.white,
          borderRadius: BorderRadius.circular(kVendorDialogRadius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 26,
                      color: accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Set stock',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.productName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Quantity on hand',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: titleColor,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: fieldFill,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(kVendorFormFieldRadius),
                    borderSide: BorderSide(
                      color: isDark
                          ? theme.colorScheme.outlineVariant.withValues(alpha: 0.7)
                          : AppColors.borderLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(kVendorFormFieldRadius),
                    borderSide: BorderSide(
                      color: isDark
                          ? theme.colorScheme.outlineVariant.withValues(alpha: 0.7)
                          : AppColors.borderLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(kVendorFormFieldRadius),
                    borderSide: BorderSide(color: accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _StockStepChip(label: '−10', onTap: () => _adjust(-10)),
                  const SizedBox(width: 8),
                  _StockStepChip(label: '−1', onTap: () => _adjust(-1)),
                  const SizedBox(width: 8),
                  _StockStepChip(label: '+1', onTap: () => _adjust(1)),
                  const SizedBox(width: 8),
                  _StockStepChip(label: '+10', onTap: () => _adjust(10)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: titleColor,
                        side: BorderSide(
                          color: isDark
                              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.85)
                              : AppColors.borderLight,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockStepChip extends StatelessWidget {
  const _StockStepChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accent = isDark ? const Color(0xFF8B7EFF) : AppColors.vendorHeroBlue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.2 : 0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.4 : 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
