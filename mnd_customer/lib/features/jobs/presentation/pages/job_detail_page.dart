import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_gradient_badge.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_application.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_booked_badge.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_owner_applicants_banner.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_quick_apply_sheet.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/jobs_flow_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class JobDetailPage extends ConsumerStatefulWidget {
  const JobDetailPage({required this.jobId, super.key});

  final String jobId;

  @override
  ConsumerState<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends ConsumerState<JobDetailPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, () async {
      try {
        await ref.read(jobsRepositoryProvider).incrementViewCount(widget.jobId);
      } catch (_) {
        // Best-effort; rules may deny client updates.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<JobListing?> jobAsync =
        ref.watch(jobDetailStreamProvider(widget.jobId));

    return jobAsync.when(
      loading: () => Scaffold(
        backgroundColor: Colors.white,
        appBar: mndPageAppBar(title: 'Job'),
        body: const JobsLoadingState(message: 'Loading job…'),
      ),
      error: (Object e, _) => Scaffold(
        backgroundColor: Colors.white,
        appBar: mndPageAppBar(title: 'Job'),
        body: JobsErrorState(
          message: 'Could not load job',
          detail: userFacingError(
            e,
            fallback: 'Could not load this job. Please try again.',
          ),
        ),
      ),
      data: (JobListing? job) {
        if (job == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: mndPageAppBar(title: 'Job'),
            body: const JobsEmptyState(
              message: 'Job not found',
              icon: Icons.work_off_outlined,
            ),
          );
        }
        final AsyncValue<Set<String>> saved = ref.watch(savedJobIdsProvider);
        final bool isSaved = saved.valueOrNull?.contains(job.id) ?? false;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: mndPageAppBar(
            title: job.title,
            actions: <Widget>[
              IconButton(
                icon: Icon(
                  isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                ),
                onPressed: () async {
                  try {
                    await ref
                        .read(jobsRepositoryProvider)
                        .toggleSaveJob(job.id);
                  } catch (e) {
                    if (context.mounted) {
                      showMndSnackBar(
                        context,
                        userFacingError(
                          e,
                          fallback: 'Could not update saved jobs.',
                        ),
                        variant: MndSnackBarVariant.error,
                      );
                    }
                  }
                },
              ),
              PopupMenuButton<String>(
                onSelected: (String v) async {
                  if (v == 'report') {
                    await _JobDetailBody.reportJob(context, ref, job.id);
                  }
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'report',
                    child: Text('Report job'),
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: JobDetailActionBar(job: job),
          body: _JobDetailBody(job: job),
        );
      },
    );
  }
}

class _JobDetailBody extends ConsumerWidget {
  const _JobDetailBody({required this.job});

  final JobListing job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double bottomClearance =
        MediaQuery.paddingOf(context).bottom + 88;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        bottomClearance,
      ),
      children: <Widget>[
        if (ref.watch(isJobOwnerProvider(job)))
          JobOwnerApplicantsBanner(job: job),
        if (ref.watch(isJobBookedForMeProvider(job.id))) ...<Widget>[
          const JobBookedBanner(),
          const SizedBox(height: AppSpacing.md),
        ],
        if (job.imageUrl != null && job.imageUrl!.isNotEmpty) ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: MndNetworkImage(
                imageUrl: job.imageUrl!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        MndPremiumCard(
          borderRadius: AppColors.cardRadiusLg,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      job.title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (ref.watch(isJobBookedForMeProvider(job.id)))
                    const JobBookedBadge(),
                  if (job.verified) ...<Widget>[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                job.companyName,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                job.salary.isNotEmpty ? job.salary : 'Negotiable',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  MndGradientBadge(label: job.type),
                  MndGradientBadge(
                    label: job.category,
                    style: MndBadgeStyle.neutral,
                  ),
                  MndGradientBadge(
                    label:
                        '${job.availableLaborCount} worker${job.availableLaborCount == 1 ? '' : 's'} needed',
                    style: MndBadgeStyle.neutral,
                  ),
                  if (job.urgent)
                    const MndGradientBadge(
                      label: 'Urgent',
                      style: MndBadgeStyle.offer,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _DetailSection(title: 'Description', body: job.description),
        if (job.responsibilities.isNotEmpty)
          _DetailSection(
            title: 'Responsibilities',
            body: job.responsibilities,
          ),
        if (job.schedule.isNotEmpty)
          _DetailSection(title: 'Work schedule', body: job.schedule),
        _DetailSection(
          title: 'Location',
          body: job.remote ? 'Remote' : job.location,
        ),
        if (job.skills.isNotEmpty)
          _DetailSection(title: 'Skills', body: job.skills.join(' · ')),
        if (job.deadline != null)
          _DetailSection(
            title: 'Application deadline',
            body: _formatDate(job.deadline!),
          ),
        _DetailSection(title: 'Contact', body: job.contactPhone),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            'Posted ${job.postedAgo}',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  static Future<void> reportJob(
    BuildContext context,
    WidgetRef ref,
    String jobId,
  ) async {
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        String value = 'Suspicious or scam';
        return AlertDialog(
          title: const Text('Report job'),
          content: DropdownButtonFormField<String>(
            value: value,
            items: <String>[
              'Suspicious or scam',
              'Duplicate listing',
              'Misleading salary',
              'Other',
            ]
                .map(
                  (String e) =>
                      DropdownMenuItem<String>(value: e, child: Text(e)),
                )
                .toList(),
            onChanged: (String? v) => value = v ?? value,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, value),
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
    if (reason == null) {
      return;
    }
    try {
      await ref.read(jobsRepositoryProvider).reportJob(
            jobId: jobId,
            reason: reason,
          );
      if (context.mounted) {
        showMndSnackBar(context, 'Report submitted. Thank you.', variant: MndSnackBarVariant.success);
      }
    } catch (e) {
      if (context.mounted) {
        showMndSnackBar(
          context,
          userFacingError(e, fallback: 'Could not submit your report.'),
          variant: MndSnackBarVariant.error,
        );
      }
    }
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: MndPremiumCard(
        borderRadius: AppColors.cardRadiusMd,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom action bar for job detail — use in scaffold bottomNavigationBar.
class JobDetailActionBar extends ConsumerWidget {
  const JobDetailActionBar({required this.job, super.key});

  final JobListing job;

  Future<void> _launchUri(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open link');
    }
  }

  Widget _barShell({required Widget child}) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isOwner = ref.watch(isJobOwnerProvider(job));
    final bool isBooked = ref.watch(isJobBookedForMeProvider(job.id));
    final String? myStatus =
        ref.watch(myApplicationStatusForJobProvider(job.id));
    final bool alreadyApplied = myStatus != null;
    final profile = ref.watch(customerProfileStreamProvider).valueOrNull;
    final bool profileReady = profile?.isProfileComplete ?? false;

    if (!job.isActive || job.isExpired) {
      return _barShell(
        child: Text(
          job.isExpired
              ? 'This listing has expired'
              : 'This job is not accepting applications',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    if (isOwner) {
      return _barShell(
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push(
              '${AppRoutes.customerJobs}/${job.id}/applications',
            ),
            icon: const Icon(Icons.people_outline_rounded),
            label: const Text('View applicants'),
          ),
        ),
      );
    }

    if (isBooked) {
      return _barShell(
        child: Row(
          children: <Widget>[
            const JobBookedBadge(),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You are booked for this job',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
            if (job.contactPhone.isNotEmpty)
              IconButton.filled(
                tooltip: 'Call employer',
                onPressed: () =>
                    _launchUri(Uri.parse('tel:${job.contactPhone}')),
                icon: const Icon(Icons.phone_rounded),
              ),
          ],
        ),
      );
    }

    if (!profileReady) {
      return _barShell(
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.customerEditProfile),
            icon: const Icon(Icons.person_outline_rounded),
            label: const Text('Complete profile to apply'),
          ),
        ),
      );
    }

    return _barShell(
      child: Row(
        children: <Widget>[
          Expanded(
            child: FilledButton(
              onPressed: alreadyApplied
                  ? null
                  : () => showJobQuickApplySheet(context, ref, job),
              child: Text(
                alreadyApplied
                    ? JobApplicationStatus.label(myStatus)
                    : 'Apply now',
              ),
            ),
          ),
          if (job.whatsapp != null && job.whatsapp!.isNotEmpty) ...<Widget>[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'WhatsApp',
              onPressed: () {
                final String digits =
                    job.whatsapp!.replaceAll(RegExp(r'\D'), '');
                _launchUri(Uri.parse('https://wa.me/$digits'));
              },
              icon: const Icon(Icons.chat_rounded),
            ),
          ],
          if (job.contactPhone.isNotEmpty) ...<Widget>[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Call',
              onPressed: () =>
                  _launchUri(Uri.parse('tel:${job.contactPhone}')),
              icon: const Icon(Icons.phone_rounded),
            ),
          ],
        ],
      ),
    );
  }
}
