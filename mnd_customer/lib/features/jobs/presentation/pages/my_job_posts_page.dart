import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_page_background.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/domain/job_constants.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/jobs_flow_widgets.dart';

class MyJobPostsPage extends ConsumerStatefulWidget {
  const MyJobPostsPage({super.key});

  @override
  ConsumerState<MyJobPostsPage> createState() => _MyJobPostsPageState();
}

class _MyJobPostsPageState extends ConsumerState<MyJobPostsPage> {
  Future<void> _refresh() async {
    ref.invalidate(myPostedJobsStreamProvider);
    await ref.read(myPostedJobsStreamProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<JobListing>> posts =
        ref.watch(myPostedJobsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('My job posts'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.customerPostJob),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Post job'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const HomePageBackground(),
          RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.brandPrimary,
            child: JobsAsyncBody<List<JobListing>>(
              async: posts,
              onRetry: _refresh,
              errorMessage: 'Could not load your job posts',
              data: (List<JobListing> jobs) {
                if (jobs.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.45,
                        child: JobsEmptyState(
                          message:
                              'You have not posted any jobs yet.\nTap Post job to create one.',
                          actionLabel: 'Post a job',
                          onAction: () => context.push(AppRoutes.customerPostJob),
                        ),
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    88,
                  ),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, int i) => _MyJobPostTile(job: jobs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MyJobPostTile extends ConsumerWidget {
  const _MyJobPostTile({required this.job});

  final JobListing job;

  void _onTap(BuildContext context) {
    if (job.status == JobConstants.statusActive) {
      context.push('${AppRoutes.customerJobs}/${job.id}/applications');
    } else {
      context.push('${AppRoutes.customerJobs}/${job.id}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<int> countAsync =
        ref.watch(jobApplicationCountProvider(job.id));
    final AsyncValue<int> bookedAsync = ref.watch(jobBookedCountProvider(job.id));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
        side: BorderSide(color: AppColors.homeMutedFill),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
        onTap: () => _onTap(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      job.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusLabel(job),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (job.status == JobConstants.statusActive) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        '${job.availableLaborCount} worker${job.availableLaborCount == 1 ? '' : 's'} · '
                        '${bookedAsync.valueOrNull ?? 0} booked',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              countAsync.when(
                data: (int n) => _ApplicantBadge(count: n),
                loading: () => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(JobListing job) {
    switch (job.status) {
      case JobConstants.statusActive:
        return 'Live — tap to manage applicants';
      case JobConstants.statusPending:
        return 'Pending approval — tap to preview';
      case JobConstants.statusRejected:
        return 'Rejected — tap to view details';
      default:
        return job.status;
    }
  }
}

class _ApplicantBadge extends StatelessWidget {
  const _ApplicantBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: count > 0
            ? AppColors.brandPrimary.withValues(alpha: 0.12)
            : AppColors.homeMutedFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count == 0 ? 'No apps' : '$count applicant${count == 1 ? '' : 's'}',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: count > 0 ? AppColors.brandPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
