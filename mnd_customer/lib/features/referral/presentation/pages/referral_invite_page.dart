import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';
import 'package:mnd_delivery_app/l10n/generated/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

class ReferralInvitePage extends ConsumerWidget {
  const ReferralInvitePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CustomerProfile?> asyncProfile =
        ref.watch(customerProfileStreamProvider);
    final String? code = asyncProfile.valueOrNull?.referralCode;

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(title: l10n.referralPageTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Icon(
            Icons.card_giftcard_rounded,
            size: 48,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.referralRewardExplainer,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          MndPremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: <Widget>[
                  Text(
                    l10n.referralYourCodeLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (code == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    Semantics(
                      label: '${l10n.referralYourCodeLabel}: $code',
                      child: ExcludeSemantics(
                        child: Text(
                          code,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                                color: AppColors.primaryBlue,
                              ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: code == null
                          ? null
                          : () {
                              unawaited(
                                SharePlus.instance.share(
                                  ShareParams(
                                    text: l10n.referralShareMessage(code),
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.share_rounded),
                      label: Text(l10n.referralShareButton),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
