import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';

class RiderSectionTitle extends StatelessWidget {
  const RiderSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: dark ? theme.colorScheme.onSurface : AppColors.textCharcoal,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
