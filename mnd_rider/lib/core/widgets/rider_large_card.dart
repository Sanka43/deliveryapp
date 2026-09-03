import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';

/// Primary content card — hairline border, no soft shadow.
class RiderLargeCard extends StatelessWidget {
  const RiderLargeCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? cs.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: borderColor ?? cs.outlineVariant,
        ),
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
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: content,
      ),
    );
  }
}
