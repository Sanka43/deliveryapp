import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';

class MndSectionHeader extends StatelessWidget {
  const MndSectionHeader({
    required this.title,
    this.actionLabel,
    this.onActionTap,
    this.accentColor,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  /// Kept for call-site compatibility; reference UI uses text actions only.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.15,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (actionLabel != null && onActionTap != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: onActionTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(
                actionLabel!,
                style: text.labelLarge?.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
