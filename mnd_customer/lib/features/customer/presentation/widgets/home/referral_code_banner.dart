import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/services/analytics_service.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';
import 'package:mnd_delivery_app/features/referral/data/referral_repository.dart';
import 'package:mnd_delivery_app/features/referral/presentation/providers/referral_repository_provider.dart';
import 'package:mnd_delivery_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kReferralBannerDismissedKey = 'referral_banner_dismissed';

/// Dismissible "have a referral code?" prompt — shown only to brand-new
/// accounts (no referredBy yet, zero orders placed) so it doesn't clutter
/// the home page for everyone else. Redemption goes through
/// [ReferralRepository], which calls the `redeemReferralCode` Cloud Function.
class ReferralCodeBanner extends ConsumerStatefulWidget {
  const ReferralCodeBanner({super.key});

  @override
  ConsumerState<ReferralCodeBanner> createState() =>
      _ReferralCodeBannerState();
}

class _ReferralCodeBannerState extends ConsumerState<ReferralCodeBanner> {
  final TextEditingController _controller = TextEditingController();
  bool _dismissed = false;
  bool _checkingDismissed = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDismissed());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadDismissed() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _dismissed = prefs.getBool(_kReferralBannerDismissedKey) ?? false;
      _checkingDismissed = false;
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReferralBannerDismissedKey, true);
  }

  Future<void> _apply() async {
    final String code = _controller.text.trim();
    if (code.isEmpty || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    final ReferralRedemptionResult result =
        await ref.read(referralRepositoryProvider).redeem(code);
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (result.isSuccess) {
      unawaited(AnalyticsService.logReferralCodeRedeemed());
      showMndSnackBar(
        context,
        l10n.referralAppliedMessage,
        variant: MndSnackBarVariant.success,
      );
      await _dismiss();
    } else {
      showMndSnackBar(
        context,
        result.errorMessage ?? l10n.referralAppliedMessage,
        variant: MndSnackBarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingDismissed || _dismissed) {
      return const SizedBox.shrink();
    }

    final CustomerProfile? profile =
        ref.watch(customerProfileStreamProvider).valueOrNull;
    final List<CustomerOrderSummary>? orders =
        ref.watch(customerOrdersStreamProvider).valueOrNull;
    final bool alreadyReferred =
        (profile?.referredBy ?? '').trim().isNotEmpty;
    if (profile == null || orders == null || alreadyReferred || orders.isNotEmpty) {
      return const SizedBox.shrink();
    }

    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        container: true,
        label: l10n.referralEnterCodeTitle,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
            border: Border.all(
              color: AppColors.brandPrimary.withValues(alpha: 0.14),
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.referralEnterCodeTitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textCapitalization: TextCapitalization.characters,
                            enabled: !_submitting,
                            decoration: InputDecoration(
                              hintText: l10n.referralEnterCodeHint,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        FilledButton(
                          onPressed: _submitting ? null : _apply,
                          child: _submitting
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(l10n.referralApplyButton),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _dismiss,
                tooltip: l10n.referralDismissTooltip,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
