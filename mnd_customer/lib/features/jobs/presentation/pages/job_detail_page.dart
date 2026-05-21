import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_page_background.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_gradient_badge.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_application.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_booked_badge.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_owner_applicants_banner.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_quick_apply_sheet.dart';
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
    Future<void>.delayed(Duration.zero, () {
      ref.read(jobsRepositoryProvider).incrementViewCount(widget.jobId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<JobListing?> jobAsync =
        ref.watch(jobDetailStreamProvider(widget.jobId));

    return jobAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Could not load job')),
      ),
      data: (JobListing? job) {
        if (job == null) {
          return const Scaffold(
            body: Center(child: Text('Job not found')),
          );
        }
        final AsyncValue<Set<String>> saved = ref.watch(savedJobIdsProvider);
        final bool isSaved = saved.valueOrNull?.contains(job.id) ?? false;
        return Scaffold(
          backgroundColor: Colors.transparent,
          bottomNavigationBar: JobDetailActionBar(job: job),
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const HomePageBackground(),
              _JobDetailBody(job: job, isSaved: isSaved),
            ],
          ),
        );
      },
    );
  }
}

class _JobDetailBody extends ConsumerWidget {
  const _JobDetailBody({required this.job, required this.isSaved});

  final JobListing job;
  final bool isSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(
                isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              ),
              onPressed: () async {
                try {
                  await ref.read(jobsRepositoryProvider).toggleSaveJob(job.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                }
              },
            ),
            PopupMenuButton<String>(
              onSelected: (String v) async {
                if (v == 'report') {
                  await _reportJob(context, ref, job.id);
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (ref.watch(isJobOwnerProvider(job)))
                  JobOwnerApplicantsBanner(job: job),
                if (ref.watch(isJobBookedForMeProvider(job.id))) ...<Widget>[
                  const JobBookedBanner(),
                  const SizedBox(height: 12),
                ],
                if (job.imageUrl != null && job.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppColors.cardRadiusLg),
                    child: SizedBox(
                      height: 180,
                      child: MndNetworkImage(
                        imageUrl: job.imageUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        job.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  job.salary.isNotEmpty ? job.salary : 'Negotiable',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    MndGradientBadge(label: job.type),
                    MndGradientBadge(label: job.category, style: MndBadgeStyle.neutral),
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
                const SizedBox(height: 20),
                _section('Description', job.description),
                if (job.responsibilities.isNotEmpty)
                  _section('Responsibilities', job.responsibilities),
                if (job.schedule.isNotEmpty)
                  _section('Work schedule', job.schedule),
                _section('Location', job.remote ? 'Remote' : job.location),
                if (job.skills.isNotEmpty)
                  _section('Skills', job.skills.join(' · ')),
                if (job.deadline != null)
                  _section(
                    'Application deadline',
                    _formatDate(job.deadline!),
                  ),
                _section('Contact', job.contactPhone),
                Text(
                  'Posted ${job.postedAgo}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  static Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _reportJob(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.')),
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

/// Bottom action bar for job detail — use in scaffold bottomNavigationBar.
class JobDetailActionBar extends ConsumerWidget {
  const JobDetailActionBar({required this.job, super.key});

  final JobListing job;

  Future<void> _launchUri(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open link');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isOwner = ref.watch(isJobOwnerProvider(job));
    final bool isBooked = ref.watch(isJobBookedForMeProvider(job.id));
    final String? myStatus = ref.watch(myApplicationStatusForJobProvider(job.id));
    final bool alreadyApplied = myStatus != null;
    final profile = ref.watch(customerProfileStreamProvider).valueOrNull;
    final bool profileReady = profile?.isProfileComplete ?? false;

    if (!job.isActive || job.isExpired) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            job.isExpired
                ? 'This listing has expired'
                : 'This job is not accepting applications',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    if (isOwner) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: <Widget>[
              const JobBookedBadge(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You are booked for this job',
                  style: GoogleFonts.plusJakartaSans(
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
        ),
      );
    }

    if (!profileReady) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.customerEditProfile),
            icon: const Icon(Icons.person_outline_rounded),
            label: const Text('Complete profile to apply'),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                onPressed: alreadyApplied
                    ? null
                    : () => showJobQuickApplySheet(context, ref, job),
                child: Text(
                  alreadyApplied
                      ? JobApplicationStatus.label(myStatus!)
                      : 'Apply now',
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (job.whatsapp != null && job.whatsapp!.isNotEmpty)
              IconButton.filled(
                tooltip: 'WhatsApp',
                onPressed: () {
                  final String digits =
                      job.whatsapp!.replaceAll(RegExp(r'\D'), '');
                  _launchUri(Uri.parse('https://wa.me/$digits'));
                },
                icon: const Icon(Icons.chat_rounded),
              ),
            if (job.contactPhone.isNotEmpty)
              IconButton.filled(
                tooltip: 'Call',
                onPressed: () =>
                    _launchUri(Uri.parse('tel:${job.contactPhone}')),
                icon: const Icon(Icons.phone_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
