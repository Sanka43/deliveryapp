import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_page_background.dart';

/// Job-related shortcuts from Profile (kept out of Settings).
class CustomerJobsMenuPage extends StatelessWidget {
  const CustomerJobsMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primary = AppColors.primaryBlue;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Jobs'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const HomePageBackground(),
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              Text(
                'Find work or hire people for your business.',
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle(title: 'Find work'),
              const SizedBox(height: AppSpacing.sm),
              _JobsMenuCard(
                children: <Widget>[
                  _JobsMenuTile(
                    icon: Icons.work_outline_rounded,
                    color: primary,
                    title: 'Browse jobs',
                    subtitle: 'Search listings and apply for work',
                    onTap: () => context.push(AppRoutes.customerJobs),
                  ),
                  const Divider(height: 1),
                  _JobsMenuTile(
                    icon: Icons.bookmark_outline_rounded,
                    color: primary,
                    title: 'Saved jobs',
                    onTap: () => context.push(AppRoutes.customerSavedJobs),
                  ),
                  const Divider(height: 1),
                  _JobsMenuTile(
                    icon: Icons.assignment_outlined,
                    color: primary,
                    title: 'My applications',
                    subtitle: 'Track applied jobs and booked status',
                    onTap: () =>
                        context.push(AppRoutes.customerMyJobApplications),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle(title: 'Hire workers'),
              const SizedBox(height: 4),
              Text(
                'Post vacancies and manage applicants.',
                style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _JobsMenuCard(
                children: <Widget>[
                  _JobsMenuTile(
                    icon: Icons.post_add_outlined,
                    color: primary,
                    title: 'Post a job',
                    subtitle: 'Admin approval required before going live',
                    onTap: () => context.push(AppRoutes.customerPostJob),
                  ),
                  const Divider(height: 1),
                  _JobsMenuTile(
                    icon: Icons.business_center_outlined,
                    color: primary,
                    title: 'My job posts',
                    subtitle: 'View applicants and book workers',
                    onTap: () => context.push(AppRoutes.customerMyJobPosts),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
    );
  }
}

class _JobsMenuCard extends StatelessWidget {
  const _JobsMenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }
}

class _JobsMenuTile extends StatelessWidget {
  const _JobsMenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
