import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_empty_state.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/admin/presentation/widgets/admin_job_approval_card.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';

/// Full list of job posts awaiting admin approval.
class AdminJobApprovalsPage extends ConsumerWidget {
  const AdminJobApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<JobListing>> pending =
        ref.watch(pendingJobsAdminProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(title: 'Approve jobs'),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<JobListing> jobs) {
          if (jobs.isEmpty) {
            return const MndEmptyState(
              icon: Icons.how_to_reg_outlined,
              title: 'No job posts waiting for approval',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, int i) => AdminJobApprovalCard(job: jobs[i]),
          );
        },
      ),
    );
  }
}
