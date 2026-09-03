import 'package:flutter/material.dart';

/// Frosted pill for map-overlaid header chrome (earnings, avatar, etc.).
class RiderMapChrome extends StatelessWidget {
  const RiderMapChrome({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.onTap,
    this.borderRadius = 12,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: dark ? 0.88 : 0.94),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: dark ? 0.8 : 1)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}
