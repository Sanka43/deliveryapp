import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          return Center(child: Text('No $status jobs'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
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
          return const Center(child: Text('No reported jobs'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(job.title, style: Theme.of(context).textTheme.titleMedium),
            Text('${job.companyName} · ${job.status}'),
            if (job.reportedCount > 0)
              Text('Reports: ${job.reportedCount}',
                  style: const TextStyle(color: Colors.orange)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
