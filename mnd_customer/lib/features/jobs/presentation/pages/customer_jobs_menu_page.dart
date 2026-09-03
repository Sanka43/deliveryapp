import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_membership_gate.dart';

/// Job-related shortcuts from Profile (kept out of Settings).
class CustomerJobsMenuPage extends ConsumerWidget {
  const CustomerJobsMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final int credits = ref.watch(jobPostCreditsProvider).valueOrNull ?? 0;
    final double bottomClearance =
        MediaQuery.paddingOf(context).bottom + AppSpacing.xl;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mndPageAppBar(title: 'Jobs'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          bottomClearance,
        ),
        children: <Widget>[
          Text(
            'Find work or hire people for your business.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          JobCreditsChip(credits: credits),
          if (credits <= 0) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const JobMembershipRequiredBanner(),
          ],
          const SizedBox(height: AppSpacing.lg),
          const MndSectionHeader(title: 'Find work'),
          const SizedBox(height: AppSpacing.sm),
          MndPremiumCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: <Widget>[
                _JobsMenuRow(
                  icon: Icons.work_outline_rounded,
                  title: 'Browse jobs',
                  subtitle: 'Search listings and apply for work',
                  onTap: () => context.push(AppRoutes.customerJobs),
                ),
                const _JobsMenuDivider(),
                _JobsMenuRow(
                  icon: Icons.bookmark_outline_rounded,
                  title: 'Saved jobs',
                  onTap: () => context.push(AppRoutes.customerSavedJobs),
                ),
                const _JobsMenuDivider(),
                _JobsMenuRow(
                  icon: Icons.assignment_outlined,
                  title: 'My applications',
                  subtitle: 'Track applied jobs and booked status',
                  onTap: () =>
                      context.push(AppRoutes.customerMyJobApplications),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const MndSectionHeader(title: 'Hire workers'),
          const SizedBox(height: 4),
          Text(
            'Post vacancies and manage applicants. Posting credits required.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          MndPremiumCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: <Widget>[
                _JobsMenuRow(
                  icon: Icons.post_add_outlined,
                  title: 'Post a job',
                  subtitle: credits > 0
                      ? 'Credits left: $credits · Admin approval required'
                      : 'Posting credits required',
                  onTap: () => context.push(AppRoutes.customerPostJob),
                ),
                const _JobsMenuDivider(),
                _JobsMenuRow(
                  icon: Icons.business_center_outlined,
                  title: 'My job posts',
                  subtitle: 'View applicants and book workers',
                  onTap: () => context.push(AppRoutes.customerMyJobPosts),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobsMenuRow extends StatelessWidget {
  const _JobsMenuRow({
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

    return MndPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.serviceJobs,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.accentPurple, size: 22),
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
    );
  }
}

class _JobsMenuDivider extends StatelessWidget {
  const _JobsMenuDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: AppSpacing.md + 40 + AppSpacing.md,
      endIndent: AppSpacing.md,
      color: Colors.black.withValues(alpha: 0.06),
    );
  }
}
