import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_page_background.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_card.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/jobs_flow_widgets.dart';

class SavedJobsPage extends ConsumerStatefulWidget {
  const SavedJobsPage({super.key});

  @override
  ConsumerState<SavedJobsPage> createState() => _SavedJobsPageState();
}

class _SavedJobsPageState extends ConsumerState<SavedJobsPage> {
  Future<void> _refresh() async {
    ref.invalidate(savedJobsStreamProvider);
    await ref.read(savedJobsStreamProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<JobListing>> saved =
        ref.watch(savedJobsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Saved jobs'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const HomePageBackground(),
          RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.brandPrimary,
            child: JobsAsyncBody<List<JobListing>>(
              async: saved,
              onRetry: _refresh,
              errorMessage: 'Could not load saved jobs',
              data: (List<JobListing> jobs) {
                if (jobs.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.45,
                        child: JobsEmptyState(
                          message:
                              'No saved jobs yet.\nBookmark listings while you browse.',
                          actionLabel: 'Browse jobs',
                          onAction: () => context.go(AppRoutes.customerJobs),
                        ),
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, int i) => JobCard(job: jobs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
