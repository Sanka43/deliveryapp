import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';

/// One tab in [VendorPillBottomNav].
class VendorNavItem {
  const VendorNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Floating capsule bottom bar: selected slot expands, others compress away.
class VendorPillBottomNav extends StatefulWidget {
  const VendorPillBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  static const Duration animDuration = Duration(milliseconds: 320);
  static const Curve animCurve = Curves.easeOutCubic;
  static const double outerMarginH = 16;
  static const double outerMarginBottom = 12;
  static const double barInset = 8;
  static const double slotHeight = 44;
  static const double barHeight = slotHeight + (barInset * 2);

  /// Gap between last scroll item and the floating nav (keep small; nav height is already included).
  static const double scrollContentExtraBottom = 12;

  /// Bottom padding for scroll views in shell tabs (clears floating nav + safe area).
  static double scrollBottomPadding(
    BuildContext context, {
    double extra = scrollContentExtraBottom,
    bool includeOuterMargin = true,
  }) {
    if (vendorUsesTabletLayout(context)) {
      return MediaQuery.paddingOf(context).bottom + 24 + extra;
    }
    return MediaQuery.paddingOf(context).bottom +
        barHeight +
        (includeOuterMargin ? outerMarginBottom : 0) +
        extra;
  }

  static const double minInactiveSlotWidth = 40;
  static const double activeIconSize = 22;
  static const double chipHPad = 14;
  static const double chipVPad = 8;
  static const double iconLabelGap = 6;

  /// Moves horizontal padding from outer edge to label side on corner tabs.
  static const double chipPaddingShift = 4;

  static double iconOnlyChipWidth() => (chipHPad * 2) + activeIconSize;

  static EdgeInsets chipPaddingFor(Alignment alignment) {
    if (alignment == Alignment.centerLeft) {
      return const EdgeInsets.fromLTRB(
        chipHPad - chipPaddingShift,
        0,
        chipHPad + chipPaddingShift,
        0,
      );
    }
    if (alignment == Alignment.centerRight) {
      return const EdgeInsets.fromLTRB(
        chipHPad + chipPaddingShift,
        0,
        chipHPad - chipPaddingShift,
        0,
      );
    }
    return const EdgeInsets.symmetric(horizontal: chipHPad);
  }

  /// Aligns active pill to outer edge on corner tabs, center on middle tabs.
  static Alignment pillAlignmentFor(int index, int itemCount) {
    if (index <= 0) {
      return Alignment.centerLeft;
    }
    if (index >= itemCount - 1) {
      return Alignment.centerRight;
    }
    return Alignment.center;
  }

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<VendorNavItem> items;

  @override
  State<VendorPillBottomNav> createState() => _VendorPillBottomNavState();
}

class _VendorPillBottomNavState extends State<VendorPillBottomNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<double> _fromShares;
  late List<double> _toShares;
  bool _sharesInitialized = false;

  List<double> _equalShares() {
    final int count = widget.items.length;
    if (count == 0) {
      return <double>[];
    }
    final double share = 1.0 / count;
    return List<double>.filled(count, share);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: VendorPillBottomNav.animDuration,
    );
    _fromShares = _equalShares();
    _toShares = _equalShares();
    _controller.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sharesInitialized) {
      _sharesInitialized = true;
      _toShares = _widthSharesForIndex(widget.currentIndex);
      _fromShares = List<double>.from(_toShares);
    }
  }

  @override
  void didUpdateWidget(VendorPillBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.items != widget.items) {
      _fromShares = _currentAnimatedShares();
      _toShares = _widthSharesForIndex(widget.currentIndex);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle _labelStyle(TextTheme textTheme) {
    return textTheme.labelMedium?.copyWith(
          color: AppColors.navBarActiveForeground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: -0.2,
        ) ??
        const TextStyle(
          color: AppColors.navBarActiveForeground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        );
  }

  double _fullChipWidth(
    VendorNavItem item,
    TextStyle style,
    Alignment pillAlignment,
  ) {
    final EdgeInsets chipPad = VendorPillBottomNav.chipPaddingFor(
      pillAlignment,
    );
    final TextPainter painter = TextPainter(
      text: TextSpan(text: item.label, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return chipPad.left +
        chipPad.right +
        VendorPillBottomNav.activeIconSize +
        VendorPillBottomNav.iconLabelGap +
        painter.width;
  }

  double get _trackWidth {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double safeWidth = screenWidth.isFinite ? screenWidth : 400;
    final double barWidth = safeWidth - (VendorPillBottomNav.outerMarginH * 2);
    return barWidth - (VendorPillBottomNav.barInset * 2);
  }

  List<double> _slotWidthsForIndex(int selectedIndex) {
    final int count = widget.items.length;
    if (count == 0) {
      return <double>[];
    }
    if (count == 1) {
      return <double>[_trackWidth];
    }

    final TextStyle labelStyle = _labelStyle(Theme.of(context).textTheme);
    final Alignment pillAlignment = VendorPillBottomNav.pillAlignmentFor(
      selectedIndex,
      count,
    );
    final double selectedChipWidth = _fullChipWidth(
      widget.items[selectedIndex],
      labelStyle,
      pillAlignment,
    );

    final int inactiveCount = count - 1;
    final double minInactiveTotal =
        VendorPillBottomNav.minInactiveSlotWidth * inactiveCount;
    final double maxActive = (_trackWidth - minInactiveTotal).clamp(
      VendorPillBottomNav.iconOnlyChipWidth(),
      _trackWidth,
    );

    double activeWidth = selectedChipWidth.clamp(
      VendorPillBottomNav.iconOnlyChipWidth(),
      maxActive,
    );
    double inactiveWidth = (_trackWidth - activeWidth) / inactiveCount;

    if (inactiveWidth < VendorPillBottomNav.minInactiveSlotWidth) {
      activeWidth = _trackWidth - minInactiveTotal;
      inactiveWidth = VendorPillBottomNav.minInactiveSlotWidth;
    }

    return List<double>.generate(
      count,
      (int i) => i == selectedIndex ? activeWidth : inactiveWidth,
    );
  }

  List<double> _widthSharesForIndex(int selectedIndex) {
    final List<double> widths = _slotWidthsForIndex(selectedIndex);
    if (widths.isEmpty || _trackWidth <= 0) {
      return widths;
    }
    return widths.map((double w) => w / _trackWidth).toList(growable: false);
  }

  List<double> _currentAnimatedShares() {
    final double t = VendorPillBottomNav.animCurve.transform(_controller.value);
    return List<double>.generate(widget.items.length, (int i) {
      return _fromShares[i] + (_toShares[i] - _fromShares[i]) * t;
    }, growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double safeWidth = screenWidth.isFinite ? screenWidth : 400;
    final double barWidth = safeWidth - (VendorPillBottomNav.outerMarginH * 2);
    final TextStyle labelStyle = _labelStyle(Theme.of(context).textTheme);

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final List<double> shares = _currentAnimatedShares();
        final double trackWidth = _trackWidth;
        final Alignment pillAlignment = VendorPillBottomNav.pillAlignmentFor(
          widget.currentIndex,
          widget.items.length,
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            VendorPillBottomNav.outerMarginH,
            0,
            VendorPillBottomNav.outerMarginH,
            VendorPillBottomNav.outerMarginBottom,
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: barWidth,
              height: VendorPillBottomNav.barHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.navBarDark,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(VendorPillBottomNav.barInset),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      width: trackWidth,
                      height: VendorPillBottomNav.slotHeight,
                      child: Row(
                        children: List<Widget>.generate(widget.items.length, (
                          int i,
                        ) {
                          final double slotWidth = shares[i] * trackWidth;
                          final bool selected = i == widget.currentIndex;

                          return SizedBox(
                            width: slotWidth,
                            height: VendorPillBottomNav.slotHeight,
                            child: _NavSlot(
                              item: widget.items[i],
                              selected: selected,
                              labelStyle: labelStyle,
                              pillAlignment: pillAlignment,
                              onTap: () {
                                if (i != widget.currentIndex) {
                                  HapticFeedback.lightImpact();
                                  widget.onTap(i);
                                }
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.item,
    required this.selected,
    required this.labelStyle,
    required this.pillAlignment,
    required this.onTap,
  });

  final VendorNavItem item;
  final bool selected;
  final TextStyle labelStyle;
  final Alignment pillAlignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        splashColor: Colors.white.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: SizedBox.expand(
          child: selected
              ? Align(
                  alignment: pillAlignment,
                  child: _ActivePill(
                    item: item,
                    labelStyle: labelStyle,
                    pillAlignment: pillAlignment,
                  ),
                )
              : Center(
                  child: Icon(
                    item.icon,
                    size: 24,
                    color: AppColors.navBarInactiveIcon,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ActivePill extends StatelessWidget {
  const _ActivePill({
    required this.item,
    required this.labelStyle,
    required this.pillAlignment,
  });

  final VendorNavItem item;
  final TextStyle labelStyle;
  final Alignment pillAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : VendorPillBottomNav.iconOnlyChipWidth();
        final EdgeInsets chipPad = VendorPillBottomNav.chipPaddingFor(
          pillAlignment,
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: SizedBox(
              height: VendorPillBottomNav.slotHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.navBarActiveChip,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: chipPad,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            item.activeIcon,
                            size: VendorPillBottomNav.activeIconSize,
                            color: AppColors.navBarActiveForeground,
                          ),
                          const SizedBox(
                            width: VendorPillBottomNav.iconLabelGap,
                          ),
                          Text(item.label, style: labelStyle, maxLines: 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
