import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_job_approvals_page.dart';
import 'package:mnd_delivery_app/features/admin/presentation/widgets/admin_job_approval_card.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';

/// Pending job listings — approve/reject directly from the admin dashboard.
class AdminDashboardJobApprovalsSection extends ConsumerWidget {
  const AdminDashboardJobApprovalsSection({super.key});

  static const int _previewLimit = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<JobListing>> pending =
        ref.watch(pendingJobsAdminProvider);
    final ThemeData theme = Theme.of(context);

    return pending.when(
      loading: () => const _SectionShell(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (Object e, _) => _SectionShell(
        child: Text('Could not load pending jobs: $e'),
      ),
      data: (List<JobListing> jobs) {
        final int count = jobs.length;
        final List<JobListing> preview = jobs.take(_previewLimit).toList();

        return _SectionShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Job approvals',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count pending',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                count == 0
                    ? 'No job posts waiting for review.'
                    : 'Review and publish local job listings.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (count == 0) ...<Widget>[
                const SizedBox(height: 16),
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 40,
                  color: AppColors.success.withValues(alpha: 0.8),
                ),
              ],
              if (preview.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                ...preview.map(
                  (JobListing job) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AdminJobApprovalCard(job: job, compact: true),
                  ),
                ),
              ],
              if (count > _previewLimit) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  '+ ${count - _previewLimit} more waiting',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminJobApprovalsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt_rounded),
                label: Text(
                  count == 0 ? 'Open job approvals' : 'View all pending ($count)',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        border: Border.all(color: AppColors.homeMutedFill),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
