import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_application.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_application_card.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/jobs_flow_widgets.dart';

class JobApplicationsPage extends ConsumerStatefulWidget {
  const JobApplicationsPage({required this.jobId, super.key});

  final String jobId;

  @override
  ConsumerState<JobApplicationsPage> createState() =>
      _JobApplicationsPageState();
}

class _JobApplicationsPageState extends ConsumerState<JobApplicationsPage> {
  Future<void> _refresh() async {
    ref.invalidate(jobApplicationsStreamProvider(widget.jobId));
    ref.invalidate(jobDetailStreamProvider(widget.jobId));
    await ref.read(jobApplicationsStreamProvider(widget.jobId).future);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AsyncValue<JobListing?> jobAsync =
        ref.watch(jobDetailStreamProvider(widget.jobId));
    final AsyncValue<List<JobApplication>> appsAsync =
        ref.watch(jobApplicationsStreamProvider(widget.jobId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mndPageAppBar(title: 'Applicants'),
      body: jobAsync.when(
        loading: () => const JobsLoadingState(),
        error: (_, __) => JobsErrorState(
          message: 'Could not load job',
          onRetry: _refresh,
        ),
        data: (JobListing? job) {
          if (job == null) {
            return const JobsEmptyState(
              message: 'Job not found',
              icon: Icons.work_off_outlined,
            );
          }
          final bool isOwner = ref.watch(isJobOwnerProvider(job));
          if (!isOwner) {
            return const JobsEmptyState(
              message: 'Only the job poster can view applicants.',
              icon: Icons.lock_outline_rounded,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.brandPrimary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: MndPremiumCard(
                    borderRadius: AppColors.cardRadiusMd,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          job.title,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Book up to ${job.availableLaborCount} worker${job.availableLaborCount == 1 ? '' : 's'}. '
                          'Applicants see “Booked” in My applications.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: appsAsync.when(
                    loading: () => const JobsLoadingState(),
                    error: (Object e, _) => JobsErrorState(
                      message: 'Could not load applicants',
                      detail: userFacingError(
                        e,
                        fallback: 'Could not load applicants. Please try again.',
                      ),
                      onRetry: _refresh,
                    ),
                    data: (List<JobApplication> apps) {
                      if (apps.isEmpty) {
                        return const JobsEmptyState(
                          message:
                              'No applications yet.\nShare your job to get applicants.',
                          icon: Icons.people_outline_rounded,
                        );
                      }
                      final List<JobApplication> booked = apps
                          .where((JobApplication a) => a.isBooked)
                          .toList();
                      final List<JobApplication> rest = apps
                          .where((JobApplication a) => !a.isBooked)
                          .toList();
                      final bool canBookMore =
                          job.hasBookingSlotsOpen(booked.length);

                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.lg,
                        ),
                        children: <Widget>[
                          MndPremiumCard(
                            borderRadius: AppColors.cardRadiusMd,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.groups_rounded,
                                  color: canBookMore
                                      ? AppColors.brandPrimary
                                      : AppColors.success,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    job.bookingSlotsLabel(booked.length),
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (!canBookMore)
                                  Text(
                                    'Full',
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (booked.isNotEmpty) ...<Widget>[
                            MndSectionHeader(
                              title: 'Booked (${booked.length})',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ...booked.map(
                              (JobApplication a) => JobApplicationCard(
                                application: a,
                                showEmployerActions: true,
                                onBook: null,
                                onShortlist: null,
                                onReject: null,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (rest.isNotEmpty) ...<Widget>[
                            const MndSectionHeader(title: 'Applications'),
                            const SizedBox(height: AppSpacing.sm),
                            ...rest.map(
                              (JobApplication a) => JobApplicationCard(
                                application: a,
                                showEmployerActions: true,
                                canBook: canBookMore,
                                onBook: () => _setStatus(
                                  ref,
                                  context,
                                  a.id,
                                  JobApplicationStatus.booked,
                                  'Worker booked',
                                ),
                                onShortlist: () => _setStatus(
                                  ref,
                                  context,
                                  a.id,
                                  JobApplicationStatus.shortlisted,
                                  'Shortlisted',
                                ),
                                onReject: () => _setStatus(
                                  ref,
                                  context,
                                  a.id,
                                  JobApplicationStatus.rejected,
                                  'Rejected',
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _setStatus(
    WidgetRef ref,
    BuildContext context,
    String applicationId,
    String status,
    String message,
  ) async {
    try {
      await ref.read(jobsRepositoryProvider).updateApplicationStatus(
            applicationId: applicationId,
            status: status,
          );
      if (context.mounted) {
        showMndSnackBar(context, message, variant: MndSnackBarVariant.success);
      }
    } catch (e) {
      if (context.mounted) {
        showMndSnackBar(
          context,
          userFacingError(e, fallback: 'Could not update this application.'),
          variant: MndSnackBarVariant.error,
        );
      }
    }
  }
}
