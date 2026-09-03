import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
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
    final bool guest = ref.watch(guestBrowsingProvider);
    final bool signedOut =
        ref.watch(firebaseAuthProvider).currentUser == null;
    if (guest || signedOut) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: mndPageAppBar(title: 'Saved jobs'),
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: const <Widget>[
            SignInRequiredBanner(
              message: 'Sign in to view and manage your saved jobs.',
              redirectTo: AppRoutes.customerSavedJobs,
            ),
          ],
        ),
      );
    }

    final AsyncValue<List<JobListing>> saved =
        ref.watch(savedJobsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mndPageAppBar(title: 'Saved jobs'),
      body: RefreshIndicator(
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
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, int i) => JobCard(job: jobs[i]),
            );
          },
        ),
      ),
    );
  }
}
