import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/widgets/rider_primary_cta.dart';

/// Icon + message + retry action for a failed load. Use this instead of a
/// bare `Center(child: Text(...))` in every `AsyncValue.error` branch, so
/// error states look and behave the same across the app.
class RiderErrorState extends StatelessWidget {
  const RiderErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_outlined,
    this.retryLabel = 'Try again',
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 56, color: cs.error.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 20),
            RiderPrimaryCta(
              label: retryLabel,
              icon: Icons.refresh,
              onPressed: onRetry,
              color: AppColors.primaryBlue,
              expanded: false,
            ),
          ],
        ],
      ),
    );
  }
}
