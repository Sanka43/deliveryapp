import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';

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
        detail: '$e',
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
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(color: AppColors.brandPrimary),
            if (message != null) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                message!,
                style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
              ),
            ],
          ],
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
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            if (detail != null && detail!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
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
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: AppColors.brandPrimary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
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
    );
  }
}
