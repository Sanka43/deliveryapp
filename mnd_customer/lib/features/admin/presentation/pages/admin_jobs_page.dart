import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/domain/job_constants.dart';
import 'package:mnd_delivery_app/features/admin/presentation/widgets/admin_job_approval_card.dart';
import 'package:mnd_delivery_app/features/jobs/data/jobs_repository.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';

class AdminJobsPage extends ConsumerStatefulWidget {
  const AdminJobsPage({super.key});

  @override
  ConsumerState<AdminJobsPage> createState() => _AdminJobsPageState();
}

class _AdminJobsPageState extends ConsumerState<AdminJobsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: AppBar(
        title: const Text('Jobs moderation'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const <Tab>[
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Expired'),
            Tab(text: 'Reported'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          _JobsTab(status: JobConstants.statusPending),
          _JobsTab(status: JobConstants.statusActive),
          _JobsTab(status: JobConstants.statusExpired),
          _ReportedJobsTab(),
        ],
      ),
    );
  }
}

class _JobsTab extends ConsumerWidget {
  const _JobsTab({required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<JobListing>> jobs =
        status == JobConstants.statusPending
            ? ref.watch(pendingJobsAdminProvider)
            : ref.watch(jobsByStatusAdminProvider(status));

    return jobs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => Center(child: Text('$e')),
      data: (List<JobListing> list) {
        if (list.isEmpty) {
          return Center(
            child: Text(
              'No $status jobs',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: list.length,
          itemBuilder: (_, int i) {
            final JobListing job = list[i];
            if (status == JobConstants.statusPending) {
              return AdminJobApprovalCard(job: job);
            }
            return _AdminJobTile(job: job);
          },
        );
      },
    );
  }
}

class _ReportedJobsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<JobListing>> jobs =
        ref.watch(activeJobsStreamProvider);
    return jobs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => Center(child: Text('$e')),
      data: (List<JobListing> list) {
        final List<JobListing> reported =
            list.where((JobListing j) => j.reportedCount > 0).toList();
        if (reported.isEmpty) {
          return Center(
            child: Text(
              'No reported jobs',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: reported.length,
          itemBuilder: (_, int i) => _AdminJobTile(job: reported[i]),
        );
      },
    );
  }
}

class _AdminJobTile extends ConsumerWidget {
  const _AdminJobTile({required this.job});

  final JobListing job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JobsRepository repo = ref.read(jobsRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: MndPremiumCard(
        borderRadius: AppColors.cardRadiusMd,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              job.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            Text(
              '${job.companyName} · ${job.status}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (job.reportedCount > 0)
              Text(
                'Reports: ${job.reportedCount}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                if (job.status == JobConstants.statusPending)
                  FilledButton(
                    onPressed: () => repo.approveJob(job.id),
                    child: const Text('Approve'),
                  ),
                if (job.status == JobConstants.statusPending)
                  OutlinedButton(
                    onPressed: () => repo.rejectJob(job.id),
                    child: const Text('Reject'),
                  ),
                OutlinedButton(
                  onPressed: () => repo.setJobVerified(job.id, !job.verified),
                  child: Text(job.verified ? 'Unverify' : 'Verify employer'),
                ),
                TextButton(
                  onPressed: () => repo.deleteJob(job.id),
                  child: const Text('Delete'),
                ),
                TextButton(
                  onPressed: () => repo.blockJobPoster(job.userId),
                  child: const Text('Block poster'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
