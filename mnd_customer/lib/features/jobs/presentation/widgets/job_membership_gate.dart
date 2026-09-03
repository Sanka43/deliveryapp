import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/constants/legal_urls.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:url_launcher/url_launcher.dart';

/// Banner when the signed-in customer has no job-post credits left.
///
/// Play-safe: no in-app purchase / WhatsApp payment CTA. Credits are granted
/// by MND admins (web dashboard) after offline arrangement.
class JobMembershipRequiredBanner extends StatelessWidget {
  const JobMembershipRequiredBanner({super.key});

  Future<void> _contactSupport() async {
    final Uri email = Uri(
      scheme: 'mailto',
      path: LegalUrls.supportEmail,
      queryParameters: <String, String>{
        'subject': 'MND job posting credits',
      },
    );
    if (await canLaunchUrl(email)) {
      await launchUrl(email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Job posting unavailable',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You need posting credits to publish a vacancy. '
            'Credits are assigned by MND — contact support if you need access.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _contactSupport,
            icon: const Icon(Icons.mail_outline_rounded, size: 18),
            label: const Text('Email support'),
          ),
        ],
      ),
    );
  }
}

/// Compact chip showing remaining job-post credits.
class JobCreditsChip extends StatelessWidget {
  const JobCreditsChip({super.key, required this.credits});

  final int credits;

  @override
  Widget build(BuildContext context) {
    final bool empty = credits <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: empty
            ? AppColors.warning.withValues(alpha: 0.12)
            : AppColors.brandPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            empty
                ? Icons.lock_outline_rounded
                : Icons.confirmation_number_outlined,
            size: 16,
            color: empty ? AppColors.warning : AppColors.brandPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            empty ? 'No job credits' : 'Job credits: $credits',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: empty ? AppColors.warning : AppColors.brandPrimary,
                ),
          ),
        ],
      ),
    );
  }
}
