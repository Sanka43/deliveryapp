import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/locale_provider.dart';
import 'package:mnd_delivery_app/core/config/env_config.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/constants/legal_urls.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_confirm_dialog.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/phone_auth_controller.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/customer_profile_avatar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/floating_glass_nav_bar.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

class CustomerSettingsPage extends ConsumerWidget {
  const CustomerSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CustomerProfile?> async =
        ref.watch(customerProfileStreamProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(title: l10n.navSettings, implyLeading: false),
      body: async.when(
        data: (CustomerProfile? profile) {
          if (profile == null) {
            return _SignedOutBody(
              onSignIn: () => navigateToSignIn(
                ref,
                context,
                redirectTo: AppRoutes.customerSettings,
              ),
            );
          }
          return _SettingsScrollContent(profile: profile);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              userFacingError(
                e,
                fallback: l10n.settingsLoadErrorFallback,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _SignedOutBody extends StatelessWidget {
  const _SignedOutBody({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double bottomClearance = floatingNavTotalHeight(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              bottomClearance,
            ),
            child: Center(
              child: MndPremiumCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _SoftIconWell(
                      icon: Icons.settings_outlined,
                      background: AppColors.primaryBlue.withValues(alpha: 0.12),
                      iconColor: AppColors.primaryBlue,
                      size: 56,
                      iconSize: 28,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppLocalizations.of(context).settingsSignInTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppLocalizations.of(context).settingsSignInSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onSignIn,
                        child: Text(AppLocalizations.of(context).actionSignIn),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsScrollContent extends ConsumerWidget {
  const _SettingsScrollContent({required this.profile});

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double bottomClearance = floatingNavTotalHeight(context);
    final bool signingOut = ref.watch(phoneAuthControllerProvider).isLoading;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              bottomClearance,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  button: true,
                  label: 'Open profile, ${profile.name}',
                  excludeSemantics: true,
                  child: MndPremiumCard(
                    onTap: () => context.push(AppRoutes.customerProfile),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: <Widget>[
                        CustomerProfileAvatar(profile: profile, size: 56),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  button: true,
                  label:
                      '${l10n.settingsJobsTitle}, ${l10n.settingsJobsSubtitle}',
                  excludeSemantics: true,
                  child: MndPremiumCard(
                    onTap: () => context.push(AppRoutes.customerProfileJobs),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: <Widget>[
                        const _SoftIconWell(
                          icon: Icons.work_outline_rounded,
                          background: AppColors.serviceJobs,
                          iconColor: AppColors.accentPurple,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                l10n.settingsJobsTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.settingsJobsSubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                MndSectionHeader(title: l10n.settingsAccountHeader),
                const SizedBox(height: AppSpacing.sm),
                MndPremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: <Widget>[
                      _SettingsRow(
                        icon: Icons.location_on_outlined,
                        title: l10n.settingsSavedAddresses,
                        onTap: () =>
                            context.push(AppRoutes.customerSavedAddresses),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.notifications_outlined,
                        title: l10n.settingsNotifications,
                        subtitle: l10n.settingsNotificationsSubtitle,
                        onTap: () => context
                            .push(AppRoutes.customerNotificationSettings),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.language_rounded,
                        title: l10n.settingsLanguage,
                        subtitle: describeAppLocaleChoice(
                          context,
                          ref.watch(appLocaleProvider).valueOrNull,
                        ),
                        onTap: () => context.push(AppRoutes.customerLanguage),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.card_giftcard_rounded,
                        title: l10n.settingsInviteFriends,
                        subtitle: l10n.settingsInviteFriendsSubtitle,
                        onTap: () => context.push(AppRoutes.customerReferral),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                MndPremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: <Widget>[
                      _SettingsRow(
                        icon: Icons.support_agent_rounded,
                        title: l10n.settingsHelpSupport,
                        subtitle: l10n.settingsHelpSupportSubtitle,
                        onTap: () => context.push(AppRoutes.customerSupport),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                MndPremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: <Widget>[
                      _SettingsRow(
                        icon: Icons.privacy_tip_outlined,
                        title: l10n.settingsPrivacyPolicy,
                        onTap: () => context.push(AppRoutes.customerPrivacy),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.description_outlined,
                        title: l10n.settingsTermsOfService,
                        onTap: () => context.push(AppRoutes.customerTerms),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: Icons.info_outline_rounded,
                        title: l10n.settingsAboutApp,
                        onTap: () => _showAbout(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SignOutButton(
                  enabled: !signingOut,
                  onPressed: () => _confirmSignOut(context, ref),
                ),
                const SizedBox(height: AppSpacing.md),
                _DeleteAccountButton(
                  enabled: !signingOut,
                  onPressed: () => _confirmDeleteAccount(context, ref),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAbout(BuildContext context) async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!context.mounted) {
      return;
    }
    final ThemeData theme = Theme.of(context);
    showAboutDialog(
      context: context,
      applicationName: EnvConfig.appTitle,
      applicationVersion: '${info.version} (${info.buildNumber})',
      applicationLegalese: '© MND Delivery\n${LegalUrls.supportEmail}',
      children: <Widget>[
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppLocalizations.of(context).settingsAboutBody,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool ok = await MndConfirmDialog.show(
      context,
      title: l10n.settingsSignOutTitle,
      message: l10n.settingsSignOutMessage,
      icon: Icons.logout_rounded,
      confirmLabel: l10n.settingsSignOutTitle,
      variant: MndConfirmDialogVariant.primary,
    );
    if (!ok || !context.mounted) {
      return;
    }
    await ref.read(phoneAuthControllerProvider.notifier).signOut();
    if (!context.mounted) {
      return;
    }
    final String? error = ref.read(phoneAuthControllerProvider).errorMessage;
    if (error != null) {
      showMndSnackBar(context, error);
      return;
    }
    ref.read(guestBrowsingProvider.notifier).state = false;
    context.go(AppRoutes.login);
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool ok = await MndConfirmDialog.show(
      context,
      title: l10n.settingsDeleteAccountTitle,
      message: l10n.settingsDeleteAccountMessage,
      icon: Icons.delete_forever_rounded,
      confirmLabel: l10n.actionDelete,
    );
    if (!ok || !context.mounted) {
      return;
    }
    await ref.read(phoneAuthControllerProvider.notifier).deleteAccount();
    if (!context.mounted) {
      return;
    }
    final String? error = ref.read(phoneAuthControllerProvider).errorMessage;
    if (error != null) {
      showMndSnackBar(context, error);
      return;
    }
    ref.read(guestBrowsingProvider.notifier).state = false;
    context.go(AppRoutes.login);
    showMndSnackBar(context, l10n.settingsAccountDeletedMessage);
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      label: subtitle != null ? '$title, $subtitle' : title,
      excludeSemantics: true,
      child: MndPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: <Widget>[
              _SoftIconWell(
                icon: icon,
                background: AppColors.primaryBlue.withValues(alpha: 0.10),
                iconColor: AppColors.primaryBlue,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: AppSpacing.md + 40 + AppSpacing.md,
      endIndent: AppSpacing.md,
      color: Colors.black.withValues(alpha: 0.06),
    );
  }
}

class _SoftIconWell extends StatelessWidget {
  const _SoftIconWell({
    required this.icon,
    required this.background,
    required this.iconColor,
    this.size = 40,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color background;
  final Color iconColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color error = AppColors.error;

    return Semantics(
      button: true,
      enabled: enabled,
      label: AppLocalizations.of(context).settingsSignOutTitle,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: MndPressable(
          onTap: enabled ? onPressed : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
              border: Border.all(color: error.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.logout_rounded, color: error, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppLocalizations.of(context).settingsSignOutTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: error,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color error = AppColors.error;

    return Semantics(
      button: true,
      enabled: enabled,
      label: AppLocalizations.of(context).settingsDeleteAccountButton,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: MndPressable(
          onTap: enabled ? onPressed : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            alignment: Alignment.center,
            child: Text(
              AppLocalizations.of(context).settingsDeleteAccountButton,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: error,
                    decoration: TextDecoration.underline,
                    decorationColor: error,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
