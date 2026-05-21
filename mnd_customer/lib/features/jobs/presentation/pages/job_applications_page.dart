import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_page_background.dart';
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
    final AsyncValue<JobListing?> jobAsync =
        ref.watch(jobDetailStreamProvider(widget.jobId));
    final AsyncValue<List<JobApplication>> appsAsync =
        ref.watch(jobApplicationsStreamProvider(widget.jobId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Applicants'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const HomePageBackground(),
          jobAsync.when(
            loading: () => const JobsLoadingState(),
            error: (_, __) => JobsErrorState(
              message: 'Could not load job',
              onRetry: _refresh,
            ),
            data: (JobListing? job) {
              if (job == null) {
                return const Center(child: Text('Job not found'));
              }
              final bool isOwner = ref.watch(isJobOwnerProvider(job));
              if (!isOwner) {
                return const Center(
                  child: Text('Only the job poster can view applicants.'),
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.brandPrimary,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text(
                      job.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text(
                      'Book up to ${job.availableLaborCount} worker${job.availableLaborCount == 1 ? '' : 's'}. '
                      'Applicants see “Booked” in My applications.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: appsAsync.when(
                      loading: () => const JobsLoadingState(),
                      error: (Object e, _) => JobsErrorState(
                        message: 'Could not load applicants',
                        detail: '$e',
                        onRetry: _refresh,
                      ),
                      data: (List<JobApplication> apps) {
                        if (apps.isEmpty) {
                          return Center(
                            child: Text(
                              'No applications yet.\nShare your job to get applicants.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textSecondary,
                              ),
                            ),
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
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.lg,
                          ),
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: canBookMore
                                    ? AppColors.brandPrimary
                                        .withValues(alpha: 0.08)
                                    : AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: canBookMore
                                      ? AppColors.brandPrimary
                                          .withValues(alpha: 0.2)
                                      : AppColors.success.withValues(alpha: 0.3),
                                ),
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
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (!canBookMore)
                                    Text(
                                      'Full',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.success,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (booked.isNotEmpty) ...<Widget>[
                              Text(
                                'Booked (${booked.length})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...booked.map(
                                (JobApplication a) => JobApplicationCard(
                                  application: a,
                                  showEmployerActions: true,
                                  onBook: null,
                                  onShortlist: null,
                                  onReject: null,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (rest.isNotEmpty) ...<Widget>[
                              Text(
                                'Applications',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
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
        ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }
}
