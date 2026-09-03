import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';

/// Loading / error / empty wrapper for jobs list screens.
class JobsAsyncBody<T> extends StatelessWidget {
  const JobsAsyncBody({
    required this.async,
    required this.data,
    this.onRetry,
    this.loadingMessage,
    this.errorMessage,
    super.key,
  });

  final AsyncValue<T> async;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final String? loadingMessage;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => JobsLoadingState(message: loadingMessage),
      error: (Object e, _) => JobsErrorState(
        message: errorMessage ?? 'Something went wrong',
        detail: userFacingError(
          e,
          fallback: errorMessage ?? 'Something went wrong. Please try again.',
        ),
        onRetry: onRetry,
      ),
      data: data,
    );
  }
}

class JobsLoadingState extends StatelessWidget {
  const JobsLoadingState({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: MndPremiumCard(
          borderRadius: AppColors.cardRadiusLg,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(color: AppColors.brandPrimary),
              if (message != null) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  message!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class JobsErrorState extends StatelessWidget {
  const JobsErrorState({
    required this.message,
    this.detail,
    this.onRetry,
    super.key,
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: MndPremiumCard(
          borderRadius: AppColors.cardRadiusLg,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _JobsIconWell(
                icon: Icons.cloud_off_rounded,
                background: AppColors.homeMutedFill,
                iconColor: AppColors.textSecondary,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (detail != null && detail!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class JobsEmptyState extends StatelessWidget {
  const JobsEmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.work_outline_rounded,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: MndPremiumCard(
          borderRadius: AppColors.cardRadiusLg,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _JobsIconWell(
                icon: icon,
                background: AppColors.serviceJobs,
                iconColor: AppColors.accentPurple,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JobsIconWell extends StatelessWidget {
  const _JobsIconWell({
    required this.icon,
    required this.background,
    required this.iconColor,
  });

  final IconData icon;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 26, color: iconColor),
    );
  }
}
