import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/utils/phone_call_launcher.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/orders/data/vendor_order_rider_contact_repository.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_order_items_list.dart';

/// Orders-tab colors — light mode values are fixed; dark mode uses adapted surfaces.
abstract final class VendorOrdersTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color canvas(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surfaceContainerLowest
      : AppColors.canvas;

  static Color primaryText(BuildContext context) =>
      isDark(context) ? Theme.of(context).colorScheme.onSurface : AppColors.textCharcoal;

  static Color mutedText(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : AppColors.textMuted;

  static Color cardSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A2030) : Colors.white;

  static Color itemsBoxFill(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.surfaceContainerHigh
      : const Color(0xFFF3F5FA);

  static Color itemsBoxBorder(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7)
      : AppColors.textCharcoal.withValues(alpha: 0.1);

  static Color chipUnselectedBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E2433) : Colors.white;

  static Color chipSelectedBg(BuildContext context) =>
      isDark(context) ? Colors.white : AppColors.textCharcoal;

  static Color chipUnselectedText(BuildContext context) => primaryText(context);

  static Color chipSelectedText(BuildContext context) =>
      isDark(context) ? AppColors.textCharcoal : Colors.white;

  static Color newBadgeBg(BuildContext context) =>
      isDark(context) ? Colors.white : AppColors.textCharcoal;

  static Color newBadgeText(BuildContext context) =>
      isDark(context) ? AppColors.textCharcoal : Colors.white;

  static Color outlineButtonBorder(BuildContext context) => isDark(context)
      ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.85)
      : AppColors.borderLight.withValues(alpha: 0.95);

  static List<BoxShadow> cardShadow(BuildContext context) {
    if (!isDark(context)) {
      return <BoxShadow>[
        BoxShadow(
          color: AppColors.textCharcoal.withValues(alpha: 0.1),
          blurRadius: 14,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.5),
        blurRadius: 18,
        offset: const Offset(0, 6),
        spreadRadius: -4,
      ),
    ];
  }

  static List<BoxShadow> chipShadow(BuildContext context, {required bool selected}) {
    if (!isDark(context)) {
      return <BoxShadow>[
        BoxShadow(
          color: AppColors.textCharcoal.withValues(alpha: selected ? 0.22 : 0.1),
          blurRadius: selected ? 16 : 12,
          offset: Offset(0, selected ? 5 : 3),
          spreadRadius: selected ? 0 : -1,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: selected ? 0.06 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: selected ? 0.55 : 0.35),
        blurRadius: selected ? 14 : 10,
        offset: Offset(0, selected ? 4 : 3),
      ),
    ];
  }
}

/// Stage accents — single brand family ([AppColors.vendorHeroBlue] → violet → green).
abstract final class VendorOrdersStageColors {
  static const Color newOrders = AppColors.vendorHeroBlue;
  static const Color kitchen = AppColors.vendorHeroViolet;
  static const Color ready = AppColors.openGreen;
  static const Color active = AppColors.textCharcoal;

  static Color forFilter(VendorOrderPipelineFilter filter) => switch (filter) {
        VendorOrderPipelineFilter.newOrders => newOrders,
        VendorOrderPipelineFilter.kitchen => kitchen,
        VendorOrderPipelineFilter.ready => ready,
        VendorOrderPipelineFilter.active => active,
      };

  static Color softFill(Color accent, {required bool isDark}) =>
      accent.withValues(alpha: isDark ? 0.14 : 0.09);

  static Color softBorder(Color accent) => accent.withValues(alpha: 0.28);
}

/// Staggered list entrance — capped delay keeps long lists lightweight.
class VendorOrdersFadeIn extends StatefulWidget {
  const VendorOrdersFadeIn({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<VendorOrdersFadeIn> createState() => _VendorOrdersFadeInState();
}

class _VendorOrdersFadeInState extends State<VendorOrdersFadeIn>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 300);
  static const int _maxStaggerIndex = 8;

  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    final CurvedAnimation curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(curve);
    final int delayMs = 28 * widget.index.clamp(0, _maxStaggerIndex);
    if (delayMs == 0) {
      _controller.forward();
    } else {
      Future<void>.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Pipeline filter row — four equal-width chips across the available width.
class VendorOrdersPipelineBar extends StatelessWidget {
  const VendorOrdersPipelineBar({
    super.key,
    required this.incomingCount,
    required this.kitchenCount,
    required this.readyCount,
    required this.activeCount,
    required this.selectedFilter,
    required this.onFilterSelected,
    this.kitchenLabel = 'Kitchen',
  });

  final int incomingCount;
  final int kitchenCount;
  final int readyCount;
  final int activeCount;
  final VendorOrderPipelineFilter selectedFilter;
  final ValueChanged<VendorOrderPipelineFilter> onFilterSelected;
  final String kitchenLabel;

  static const double _chipGap = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const int chipCount = 4;
        const double minChipWidth = 64;
        final double totalGaps = _chipGap * (chipCount - 1);
        final bool useScroll =
            constraints.maxWidth < minChipWidth * chipCount + totalGaps;

        final List<_PipelineChip> chips = <_PipelineChip>[
          _PipelineChip(
            label: 'New',
            value: incomingCount,
            selected: selectedFilter == VendorOrderPipelineFilter.newOrders,
            onTap: () => onFilterSelected(VendorOrderPipelineFilter.newOrders),
            fixedWidth: useScroll ? _PipelineChip.scrollWidth : null,
          ),
          _PipelineChip(
            label: kitchenLabel,
            value: kitchenCount,
            selected: selectedFilter == VendorOrderPipelineFilter.kitchen,
            onTap: () => onFilterSelected(VendorOrderPipelineFilter.kitchen),
            fixedWidth: useScroll ? _PipelineChip.scrollWidth : null,
          ),
          _PipelineChip(
            label: 'Ready',
            value: readyCount,
            selected: selectedFilter == VendorOrderPipelineFilter.ready,
            onTap: () => onFilterSelected(VendorOrderPipelineFilter.ready),
            fixedWidth: useScroll ? _PipelineChip.scrollWidth : null,
          ),
          _PipelineChip(
            label: 'Active',
            value: activeCount,
            selected: selectedFilter == VendorOrderPipelineFilter.active,
            onTap: () => onFilterSelected(VendorOrderPipelineFilter.active),
            fixedWidth: useScroll ? _PipelineChip.scrollWidth : null,
          ),
        ];

        if (useScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            child: Row(children: _interleaveChips(chips)),
          );
        }

        return Row(children: _interleaveChips(chips, expanded: true));
      },
    );
  }

  List<Widget> _interleaveChips(List<_PipelineChip> chips, {bool expanded = false}) {
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < chips.length; i++) {
      if (i > 0) {
        out.add(const SizedBox(width: _chipGap));
      }
      out.add(expanded ? Expanded(child: chips[i]) : chips[i]);
    }
    return out;
  }
}

class _PipelineChip extends StatefulWidget {
  const _PipelineChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    this.fixedWidth,
  });

  static const double scrollWidth = 82;

  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;
  final double? fixedWidth;

  @override
  State<_PipelineChip> createState() => _PipelineChipState();
}

class _PipelineChipState extends State<_PipelineChip> {
  bool _pressed = false;

  void _handleTap() {
    HapticFeedback.selectionClick();
    setState(() => _pressed = true);
    widget.onTap();
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() => _pressed = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color textColor = widget.selected
        ? VendorOrdersTheme.chipSelectedText(context)
        : VendorOrdersTheme.chipUnselectedText(context);
    final Color bg = widget.selected
        ? VendorOrdersTheme.chipSelectedBg(context)
        : VendorOrdersTheme.chipUnselectedBg(context);

    final Widget chip = GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: VendorOrdersTheme.chipShadow(context, selected: widget.selected),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: theme.textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1,
                    color: textColor,
                    fontSize: 22,
                  ),
                  child: Text('${widget.value}', textAlign: TextAlign.center),
                ),
                const SizedBox(height: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: theme.textTheme.labelSmall!.copyWith(
                    color: textColor.withValues(alpha: widget.selected ? 0.92 : 1),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.35,
                    fontSize: 10,
                    height: 1.2,
                  ),
                  child: Text(
                    widget.label.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

    return SizedBox(
      width: widget.fixedWidth ?? double.infinity,
      child: chip,
    );
  }
}

/// Section heading for order groups.
class VendorOrdersSectionHeader extends StatelessWidget {
  const VendorOrdersSectionHeader({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: VendorOrdersStageColors.softFill(accent, isDark: isDark),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: VendorOrdersTheme.primaryText(context),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Container(
            key: ValueKey<int>(count),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: VendorOrdersStageColors.softFill(accent, isDark: isDark),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: VendorOrdersStageColors.softBorder(accent)),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: accent,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Placed-at time — icon + text, no background.
class _OrderPlacedAtBadge extends StatelessWidget {
  const _OrderPlacedAtBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color ink = VendorOrdersTheme.primaryText(context);
    final bool isJustNow = label.trim().isEmpty;
    final String display = isJustNow ? 'Just now' : label.trim();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.schedule_rounded,
          size: 16,
          color: ink.withValues(alpha: 0.88),
        ),
        const SizedBox(width: 6),
        Text(
          display,
          style: theme.textTheme.labelLarge?.copyWith(
            color: ink,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.1,
            height: 1.15,
            fontFeatures: isJustNow ? null : const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

enum VendorOrderCardStage { urgent, progress, ready }

/// Order pipeline card — stage-tinted surface and CTA.
class VendorOrderListCard extends StatefulWidget {
  const VendorOrderListCard({
    super.key,
    required this.order,
    required this.stage,
    required this.amountLabel,
    required this.onOpen,
    required this.onPrimary,
    required this.primaryLabel,
    required this.onSecondary,
    required this.secondaryLabel,
  });

  final VendorPendingOrder order;
  final VendorOrderCardStage stage;
  final String amountLabel;
  final VoidCallback onOpen;
  final Future<void> Function()? onPrimary;
  final String primaryLabel;
  final Future<void> Function()? onSecondary;
  final String? secondaryLabel;

  @override
  State<VendorOrderListCard> createState() => _VendorOrderListCardState();
}

class _VendorOrderListCardState extends State<VendorOrderListCard> {
  bool _primaryPressed = false;
  bool _primaryBusy = false;

  Color get _stageAccent => switch (widget.stage) {
        VendorOrderCardStage.urgent => VendorOrdersStageColors.newOrders,
        VendorOrderCardStage.progress => VendorOrdersStageColors.kitchen,
        VendorOrderCardStage.ready => VendorOrdersStageColors.ready,
      };

  Future<void> _runPrimary() async {
    // Guards against a fast double-tap firing the status-update write (and
    // its rider-matching notification) twice before the first call lands.
    if (widget.onPrimary == null || _primaryBusy) {
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _primaryPressed = true;
      _primaryBusy = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 85));
    if (mounted) {
      setState(() => _primaryPressed = false);
    }
    try {
      await widget.onPrimary!();
    } finally {
      if (mounted) {
        setState(() => _primaryBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final VendorPendingOrder order = widget.order;
    final String itemsLabel = order.itemCount == 1 ? '1 item' : '${order.itemCount} items';
    final Color cardBg = VendorOrdersTheme.cardSurface(context);
    final Color titleColor = VendorOrdersTheme.primaryText(context);
    final Color mutedColor = VendorOrdersTheme.mutedText(context);
    final bool hasItemLines = order.itemLines.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: VendorOrdersTheme.cardShadow(context),
      ),
      child: Material(
        color: cardBg,
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onOpen,
          splashColor: _stageAccent.withValues(alpha: 0.06),
          highlightColor: _stageAccent.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            order.referenceForDisplay,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: titleColor,
                              height: 1.15,
                              fontSize: 17,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (order.customerName.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              order.customerName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (order.customerPhone.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () =>
                                  launchPhoneCall(context, order.customerPhone),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.call_rounded,
                                    size: 13,
                                    color: AppColors.openGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      order.customerPhone,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: mutedColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        _OrderPlacedAtBadge(label: order.placedAtLabel),
                        if (order.isVendorManual) ...<Widget>[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.pendingAmber.withValues(
                                alpha: VendorOrdersTheme.isDark(context)
                                    ? 0.22
                                    : 0.16,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              order.isGuestCustomer ? 'PHONE' : 'MANUAL',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textCharcoal,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                        if (order.hasProductCashLedger) ...<Widget>[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: order.productCashStatus == 'settled_to_shop'
                                  ? AppColors.openGreen.withValues(alpha: 0.16)
                                  : AppColors.pendingAmber.withValues(
                                      alpha: 0.16,
                                    ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              order.productCashBadgeLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textCharcoal,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                        if (widget.stage == VendorOrderCardStage.urgent) ...<Widget>[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: VendorOrdersTheme.newBadgeBg(context),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'NEW',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: VendorOrdersTheme.newBadgeText(context),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.shopping_bag_outlined, size: 14, color: mutedColor),
                    const SizedBox(width: 5),
                    Text(
                      itemsLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.amountLabel,
                      style: GoogleFonts.poppins(
                        textStyle: theme.textTheme.titleMedium,
                        color: titleColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 17,
                        letterSpacing: -0.2,
                        height: 1.1,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (hasItemLines) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    decoration: BoxDecoration(
                      color: VendorOrdersTheme.itemsBoxFill(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: VendorOrdersTheme.itemsBoxBorder(context),
                      ),
                    ),
                    child: VendorOrderItemsList(
                      items: order.items,
                      primaryText: titleColor,
                      mutedText: mutedColor,
                    ),
                  ),
                ],
                if (order.hasAssignedRider) ...<Widget>[
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (BuildContext context, WidgetRef ref, _) {
                      final AsyncValue<VendorOrderRiderContact> contact = ref
                          .watch(vendorOrderRiderContactProvider(order.id));
                      return contact.maybeWhen(
                        data: (VendorOrderRiderContact c) => InkWell(
                          onTap: () => launchPhoneCall(context, c.phone),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.delivery_dining_rounded,
                                size: 15,
                                color: VendorOrdersStageColors.kitchen,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Call rider · ${c.name}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: VendorOrdersStageColors.kitchen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
                if (widget.onPrimary != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      if (widget.onSecondary != null && widget.secondaryLabel != null) ...<Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onSecondary,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: titleColor,
                              backgroundColor: cardBg,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: VendorOrdersTheme.outlineButtonBorder(context),
                              ),
                              textStyle: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            child: Text(widget.secondaryLabel!),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: AnimatedScale(
                          scale: _primaryPressed ? 0.97 : 1,
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeOut,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: _stageAccent.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: FilledButton(
                              onPressed: _primaryBusy ? null : _runPrimary,
                              style: FilledButton.styleFrom(
                                backgroundColor: _stageAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              child: _primaryBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(widget.primaryLabel),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
