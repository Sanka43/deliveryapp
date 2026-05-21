import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/phone_auth_controller.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';
import 'package:mnd_delivery_app/app/providers/locale_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';

class CustomerProfilePage extends ConsumerWidget {
  const CustomerProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CustomerProfile?> async = ref.watch(customerProfileStreamProvider);

    return Scaffold(
      body: async.when(
        data: (CustomerProfile? profile) {
          if (profile == null) {
            return _SignedOutBody(
              onSignIn: () => context.push(AppRoutes.login),
            );
          }
          return _ProfileScrollContent(profile: profile);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Could not load profile.\n$e',
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
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar.large(
          title: const Text('Profile'),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
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
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: onSignIn,
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileScrollContent extends ConsumerWidget {
  const _ProfileScrollContent({required this.profile});

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Color primary = AppColors.primaryBlue;

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          expandedHeight: 0,
          pinned: true,
          title: const Text('Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        primary.withValues(alpha: 0.12),
                        primary.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      _ProfileAvatar(profile: profile),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              profile.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile.phone.isEmpty ? 'No phone on file' : profile.phone,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.black54,
                                  ),
                            ),
                            if (profile.email != null && profile.email!.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                profile.email!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.black45,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
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
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Personal information',
                        style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.customerEditProfile),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: <Widget>[
                      _InfoTile(
                        icon: Icons.badge_outlined,
                        label: 'Full name',
                        value: profile.name,
                      ),
                      const Divider(height: 1),
                      _InfoTile(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: profile.phone.isEmpty ? '—' : profile.phone,
                      ),
                      const Divider(height: 1),
                      _InfoTile(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email',
                        value: (profile.email != null && profile.email!.isNotEmpty)
                            ? profile.email!
                            : 'Not added',
                      ),
                      if (profile.photoUrl != null &&
                          profile.photoUrl!.isNotEmpty) ...<Widget>[
                        const Divider(height: 1),
                        _InfoTile(
                          icon: Icons.photo_outlined,
                          label: 'Profile photo',
                          value: 'Added',
                        ),
                      ],
                      const Divider(height: 1),
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
                const SizedBox(height: AppSpacing.lg),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.work_outline_rounded, color: primary),
                    title: const Text('Jobs'),
                    subtitle: const Text(
                      'Find work, applications, saved jobs, and hiring.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.customerProfileJobs),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Settings',
                  style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: Icon(Icons.receipt_long_outlined, color: primary),
                        title: const Text('My orders'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(AppRoutes.customerOrders),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.location_on_outlined, color: primary),
                        title: const Text('Saved addresses'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(AppRoutes.customerSavedAddresses),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.notifications_outlined, color: primary),
                        title: const Text('Notifications'),
                        subtitle: const Text(
                          'Choose order alerts and offers.',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(AppRoutes.customerNotificationSettings),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.language_rounded, color: primary),
                        title: const Text('Language'),
                        subtitle: Text(
                          describeAppLocaleChoice(ref.watch(appLocaleProvider).valueOrNull),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(AppRoutes.customerLanguage),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline_rounded, color: primary),
                  title: const Text('About this app'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'MND Delivery',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '',
                      children: <Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Order food and groceries for delivery in your area.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                  onPressed: ref.watch(phoneAuthControllerProvider).isLoading
                      ? null
                      : () => _confirmSignOut(context, ref),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Do you want to sign out from this account?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    await ref.read(phoneAuthControllerProvider.notifier).signOut();
    if (!context.mounted) {
      return;
    }
    final String? error = ref.read(phoneAuthControllerProvider).errorMessage;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ref.read(guestBrowsingProvider.notifier).state = false;
    context.go(AppRoutes.login);
  }
}

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard({required this.profile});

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double progress = profile.profileCompletionPercent / 100;

    return Material(
      color: AppColors.offerOrange.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(AppRoutes.customerEditProfile),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.person_pin_outlined,
                    color: AppColors.offerOrange,
                  ),
                  const SizedBox(width: 10),
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
              const SizedBox(height: 10),
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
                'Required before you apply to jobs.',
                style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
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
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    final String? url = profile.photoUrl;
    final double size = 88;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _InitialsFallback(profile: profile),
            )
          : _InitialsFallback(profile: profile),
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({required this.profile});

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primaryBlue.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          profile.initials,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
        ),
      ),
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
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22, color: Colors.black45),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
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
