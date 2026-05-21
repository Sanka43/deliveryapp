import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_page_background.dart';
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
    ref.invalidate(activeJobsStreamProvider);
    ref.invalidate(savedJobIdsProvider);
    ref.invalidate(myJobApplicationsStreamProvider);
    await ref.read(activeJobsStreamProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<JobListing>> jobsAsync =
        ref.watch(activeJobsStreamProvider);
    final List<JobListing> all = jobsAsync.valueOrNull ?? const <JobListing>[];
    final List<JobListing> filtered = ref.watch(filteredJobsProvider);
    final JobsFilterState filter = ref.watch(jobsFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const HomePageBackground(),
          RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.brandPrimary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: <Widget>[
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  backgroundColor: AppColors.homeBlueBottom.withValues(alpha: 0.92),
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                    onPressed: () => context.pop(),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Jobs',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Find work and apply in a few taps',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  actions: <Widget>[
                    _HeaderIconButton(
                      icon: Icons.bookmark_outline_rounded,
                      tooltip: 'Saved jobs',
                      onPressed: () => context.push(AppRoutes.customerSavedJobs),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    100,
                  ),
                  sliver: jobsAsync.when(
                    loading: () => const SliverFillRemaining(
                      hasScrollBody: false,
                      child: JobsLoadingState(message: 'Loading jobs…'),
                    ),
                    error: (Object e, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: JobsErrorState(
                        message: 'Could not load jobs',
                        detail: '$e',
                        onRetry: _refresh,
                      ),
                    ),
                    data: (_) => SliverList(
                      delegate: SliverChildListDelegate(
                        <Widget>[
                          const JobsSearchHeader(),
                          const SizedBox(height: AppSpacing.md),
                          const JobsCategoryChips(),
                          const SizedBox(height: AppSpacing.lg),
                          if (all.isEmpty)
                            const _JobsEmptyPanel(
                              message:
                                  'No jobs live right now.\nPull down to refresh or check back soon.',
                              icon: Icons.work_off_outlined,
                            )
                          else ...<Widget>[
                            if (all.isNotEmpty) _JobsStatsStrip(count: all.length),
                            const SizedBox(height: AppSpacing.lg),
                            JobsHorizontalSection(
                              title: 'Trending',
                              jobs: trendingJobs(all),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            JobsHorizontalSection(
                              title: 'Urgent hiring',
                              jobs: urgentJobs(all),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            JobsHorizontalSection(
                              title: 'Latest',
                              jobs: latestJobs(all),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            JobsHorizontalSection(
                              title: 'Recommended',
                              jobs: recommendedJobs(all, filter),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _AllJobsHeader(
                              title: filter.query.isNotEmpty ||
                                      filter.category != null ||
                                      filter.locationLabel != 'Near you'
                                  ? 'Results'
                                  : 'All jobs',
                              count: filtered.length,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            if (filtered.isEmpty)
                              const _JobsEmptyPanel(
                                message:
                                    'No jobs match your filters.\nTry another category or location.',
                              )
                            else
                              ...filtered.map(
                                (JobListing j) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,
                                  ),
                                  child: JobCard(job: j),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
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

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: AppColors.brandPrimary),
          ),
        ),
      ),
    );
  }
}

class _JobsStatsStrip extends StatelessWidget {
  const _JobsStatsStrip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.work_rounded,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$count open positions',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Updated live — pull to refresh',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

class _AllJobsHeader extends StatelessWidget {
  const _AllJobsHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobsEmptyPanel extends StatelessWidget {
  const _JobsEmptyPanel({
    required this.message,
    this.icon = Icons.work_outline_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 48, color: AppColors.brandPrimary.withValues(alpha: 0.45)),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textSecondary,
              height: 1.45,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
