import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/customer_profile_avatar.dart';

class CustomerProfilePage extends ConsumerWidget {
  const CustomerProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CustomerProfile?> async =
        ref.watch(customerProfileStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(title: 'Profile'),
      body: async.when(
        data: (CustomerProfile? profile) {
          if (profile == null) {
            return _SignedOutBody(
              onSignIn: () => navigateToSignIn(
                ref,
                context,
                redirectTo: AppRoutes.customerProfile,
              ),
            );
          }
          return _ProfileScrollContent(profile: profile);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              userFacingError(
                e,
                fallback: 'Could not load profile. Please try again.',
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.account_circle_outlined,
            size: 88,
            color: AppColors.primaryBlue.withValues(alpha: 0.65),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Sign in to view your profile',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Save addresses, track orders, and manage your account.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onSignIn,
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

class _ProfileScrollContent extends StatelessWidget {
  const _ProfileScrollContent({required this.profile});

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasPhoto =
        profile.photoUrl != null && profile.photoUrl!.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary,
            borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
          ),
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: CustomerProfileAvatar(profile: profile, size: 96),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                profile.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                profile.phone.isEmpty ? 'No phone on file' : profile.phone,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              if (profile.email != null && profile.email!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  profile.email!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.customerEditProfile),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.brandPrimary,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit profile'),
                ),
              ),
            ],
          ),
        ),
        if (!profile.isProfileComplete) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _ProfileCompletionCard(profile: profile),
        ],
        const SizedBox(height: AppSpacing.lg),
        const MndSectionHeader(title: 'Personal information'),
        const SizedBox(height: AppSpacing.sm),
        MndPremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              _InfoTile(
                icon: Icons.badge_outlined,
                label: 'Full name',
                value: profile.name,
              ),
              const _InfoDivider(),
              _InfoTile(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: profile.phone.isEmpty ? '—' : profile.phone,
              ),
              const _InfoDivider(),
              _InfoTile(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: (profile.email != null && profile.email!.isNotEmpty)
                    ? profile.email!
                    : 'Not added',
              ),
              const _InfoDivider(),
              _InfoTile(
                icon: Icons.photo_outlined,
                label: 'Profile photo',
                value: hasPhoto ? 'Added' : 'Not added',
              ),
              const _InfoDivider(),
              _InfoTile(
                icon: Icons.verified_user_outlined,
                label: 'Profile status',
                value: profile.isProfileComplete
                    ? 'Complete'
                    : '${profile.profileCompletionPercent}% complete',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard({required this.profile});

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double progress = profile.profileCompletionPercent / 100;

    return MndPremiumCard(
      onTap: () => context.push(AppRoutes.customerEditProfile),
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
          color: AppColors.offerOrange.withValues(alpha: 0.08),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.offerOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_pin_outlined,
                    color: AppColors.offerOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Complete your profile',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${profile.profileCompletionPercent}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.offerOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.black.withValues(alpha: 0.06),
                color: AppColors.offerOrange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add: ${profile.missingProfileFields.join(', ')}. '
              'Complete your profile for a smoother experience.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Edit profile →',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: AppSpacing.md + 22 + AppSpacing.md,
      color: Colors.black.withValues(alpha: 0.06),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
