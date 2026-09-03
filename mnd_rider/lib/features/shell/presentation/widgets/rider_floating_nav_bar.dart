import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';

/// Floating bottom nav — soft selected pill, rider-focused icons.
class RiderFloatingNavBar extends StatelessWidget {
  const RiderFloatingNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const double barHeight = 64;
  static const double bottomGap = 10;

  static const List<({IconData icon, IconData selectedIcon, String label})>
      _items = <({IconData icon, IconData selectedIcon, String label})>[
    (
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      label: 'Home',
    ),
    (
      icon: Icons.local_shipping_outlined,
      selectedIcon: Icons.local_shipping_rounded,
      label: 'Jobs',
    ),
    (
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: 'Earnings',
    ),
    (
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final double bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        bottom + bottomGap,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: dark ? 0.85 : 1),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.32 : 0.07),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SizedBox(
          height: barHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: List<Widget>.generate(_items.length, (int index) {
                final item = _items[index];
                final bool selected = index == selectedIndex;
                return Expanded(
                  child: _NavItem(
                    icon: selected ? item.selectedIcon : item.icon,
                    label: item.label,
                    selected: selected,
                    onTap: () {
                      if (index != selectedIndex) {
                        HapticFeedback.selectionClick();
                      }
                      onDestinationSelected(index);
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = selected ? cs.primary : cs.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: cs.primary.withValues(alpha: 0.08),
        highlightColor: cs.primary.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedScale(
                scale: selected ? 1.06 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(icon, size: 22, color: fg),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 10.5,
                      height: 1,
                      letterSpacing: selected ? 0.1 : 0,
                    ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom inset reserved for floating nav + safe area.
double riderFloatingNavTotalHeight(BuildContext context) {
  return RiderFloatingNavBar.barHeight +
      MediaQuery.paddingOf(context).bottom +
      RiderFloatingNavBar.bottomGap +
      8;
}
