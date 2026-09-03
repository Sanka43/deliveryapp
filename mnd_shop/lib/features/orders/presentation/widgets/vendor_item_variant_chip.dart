import 'package:flutter/material.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';

/// Chip for what the customer actually picked on an order line.
///
/// The size/variant is what the kitchen has to read, so it gets a tinted,
/// bordered chip at body size rather than a faint grey label; add-ons use the
/// amber variant so they can't be mistaken for the variant itself.
class VendorItemVariantChip extends StatelessWidget {
  const VendorItemVariantChip.variant({super.key, required this.text})
      : accent = AppColors.primaryBlue,
        icon = Icons.local_offer_rounded;

  const VendorItemVariantChip.extra({super.key, required this.text})
      : accent = AppColors.pendingAmber,
        icon = Icons.add_rounded;

  final String text;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    // Dark surfaces need the chip text lifted off the tint, light ones need it
    // pushed down for contrast against the pale fill.
    final Color foreground = isDark
        ? Color.lerp(accent, Colors.white, 0.55) ?? accent
        : Color.lerp(accent, Colors.black, 0.35) ?? accent;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: isDark ? 0.5 : 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
