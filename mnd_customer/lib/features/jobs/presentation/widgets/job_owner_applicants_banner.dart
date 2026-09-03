import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';

/// Shown on job detail when the signed-in user posted this job.
class JobOwnerApplicantsBanner extends ConsumerWidget {
  const JobOwnerApplicantsBanner({required this.job, super.key});

  final JobListing job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AsyncValue<int> countAsync =
        ref.watch(jobApplicationCountProvider(job.id));
    final AsyncValue<int> bookedAsync =
        ref.watch(jobBookedCountProvider(job.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MndPremiumCard(
        borderRadius: AppColors.cardRadiusMd,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Your job post',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  countAsync.when(
                    data: (int n) {
                      final int booked = bookedAsync.valueOrNull ?? 0;
                      final String slots = job.bookingSlotsLabel(booked);
                      return Text(
                        n == 0
                            ? '$slots · no applications yet'
                            : '$slots · $n applicant${n == 1 ? '' : 's'}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => context.push(
                '${AppRoutes.customerJobs}/${job.id}/applications',
              ),
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }
}
