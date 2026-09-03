import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_card.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/jobs_category_chips.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/jobs_flow_widgets.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/jobs_horizontal_section.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/jobs_search_header.dart';

class JobsHomePage extends ConsumerStatefulWidget {
  const JobsHomePage({super.key});

  @override
  ConsumerState<JobsHomePage> createState() => _JobsHomePageState();
}

class _JobsHomePageState extends ConsumerState<JobsHomePage> {
  Future<void> _refresh() async {
    ref.read(activeJobsLimitProvider.notifier).state = 80;
    ref.invalidate(activeJobsStreamProvider);
    ref.invalidate(savedJobIdsProvider);
    ref.invalidate(myJobApplicationsStreamProvider);
    await ref.read(activeJobsStreamProvider.future);
  }

  bool _isFiltered(JobsFilterState filter) {
    return filter.query.isNotEmpty ||
        filter.category != null ||
        filter.jobType != null ||
        filter.remoteOnly ||
        filter.locationLabel != 'Near you';
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<JobListing>> jobsAsync =
        ref.watch(activeJobsStreamProvider);
    final List<JobListing> all = jobsAsync.valueOrNull ?? const <JobListing>[];
    final List<JobListing> filtered = ref.watch(filteredJobsProvider);
    final JobsFilterState filter = ref.watch(jobsFilterProvider);
    final bool filteredMode = _isFiltered(filter);
    final String resultsTitle = filteredMode ? 'Results' : 'All jobs';
    final double bottomPad =
        MediaQuery.paddingOf(context).bottom + AppSpacing.xl;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mndPageAppBar(
        title: 'Jobs',
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.post_add_outlined),
            tooltip: 'Post a job',
            onPressed: () => context.push(AppRoutes.customerPostJob),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline_rounded),
            tooltip: 'Saved jobs',
            onPressed: () => context.push(AppRoutes.customerSavedJobs),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.brandPrimary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            if (jobsAsync.isLoading && all.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: JobsLoadingState(message: 'Loading jobs…'),
              )
            else if (jobsAsync.hasError && all.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: JobsErrorState(
                  message: 'Could not load jobs',
                  detail: '${jobsAsync.error}',
                  onRetry: _refresh,
                ),
              )
            else ...<Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const JobsSearchHeader(),
                      const SizedBox(height: AppSpacing.md),
                      const JobsCategoryChips(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
              if (all.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    bottomPad,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: JobsEmptyState(
                      message:
                          'No jobs live right now.\nPull down to refresh or check back soon.',
                      icon: Icons.work_off_outlined,
                    ),
                  ),
                )
              else if (filteredMode) ...<Widget>[
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverToBoxAdapter(
                    child: _JobsCountHeader(
                      title: resultsTitle,
                      count: filtered.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.sm),
                ),
                if (filtered.isEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      bottomPad,
                    ),
                    sliver: const SliverToBoxAdapter(
                      child: JobsEmptyState(
                        message:
                            'No jobs match your filters.\nTry another category or location.',
                      ),
                    ),
                  )
                else ...<Widget>[
                  _JobsListSliver(jobs: filtered, bottomPad: AppSpacing.sm),
                  _LoadMoreJobsSliver(
                    loadedCount: all.length,
                    isLoading: jobsAsync.isLoading,
                    bottomPad: bottomPad,
                  ),
                ],
              ] else ...<Widget>[
                _SoftHorizontal(
                  child: JobsHorizontalSection(
                    title: 'Urgent hiring',
                    jobs: urgentJobs(all),
                  ),
                ),
                const _SoftGap(),
                _SoftHorizontal(
                  child: JobsHorizontalSection(
                    title: 'Latest',
                    jobs: latestJobs(all),
                  ),
                ),
                const _SoftGap(),
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverToBoxAdapter(
                    child: _JobsCountHeader(
                      title: 'All jobs',
                      count: filtered.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.sm),
                ),
                if (filtered.isEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      bottomPad,
                    ),
                    sliver: const SliverToBoxAdapter(
                      child: JobsEmptyState(
                        message: 'No jobs to show right now.',
                      ),
                    ),
                  )
                else ...<Widget>[
                  _JobsListSliver(jobs: filtered, bottomPad: AppSpacing.sm),
                  _LoadMoreJobsSliver(
                    loadedCount: all.length,
                    isLoading: jobsAsync.isLoading,
                    bottomPad: bottomPad,
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _JobsCountHeader extends StatelessWidget {
  const _JobsCountHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.15,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          ),
          child: Text(
            '$count',
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.brandPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _JobsListSliver extends StatelessWidget {
  const _JobsListSliver({required this.jobs, required this.bottomPad});

  final List<JobListing> jobs;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        bottomPad,
      ),
      sliver: SliverList.builder(
        itemCount: jobs.length,
        itemBuilder: (BuildContext context, int index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: JobCard(job: jobs[index]),
          );
        },
      ),
    );
  }
}

class _LoadMoreJobsSliver extends ConsumerWidget {
  const _LoadMoreJobsSliver({
    required this.loadedCount,
    required this.isLoading,
    required this.bottomPad,
  });

  final int loadedCount;
  final bool isLoading;
  final double bottomPad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int limit = ref.watch(activeJobsLimitProvider);
    // loadedCount can only reach limit if there may be more beyond the page.
    if (loadedCount < limit) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, bottomPad),
      sliver: SliverToBoxAdapter(
        child: Center(
          child: TextButton(
            onPressed: isLoading
                ? null
                : () => ref.read(activeJobsLimitProvider.notifier).state =
                    limit + 80,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Load more jobs'),
          ),
        ),
      ),
    );
  }
}

class _SoftHorizontal extends StatelessWidget {
  const _SoftHorizontal({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}

class _SoftGap extends StatelessWidget {
  const _SoftGap();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg));
  }
}

