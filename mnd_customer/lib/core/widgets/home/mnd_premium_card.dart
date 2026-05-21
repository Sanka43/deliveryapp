import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';

class MndPremiumCard extends StatelessWidget {
  const MndPremiumCard({
    required this.child,
    this.onTap,
    this.borderRadius = AppColors.cardRadiusMd,
    this.padding,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppColors.shadowElevated,
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }
    return MndPressable(
      onTap: onTap,
      child: content,
    );
  }
}
