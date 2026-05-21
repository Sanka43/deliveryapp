import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(
        title: const Text('Approve jobs'),
      ),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<JobListing> jobs) {
          if (jobs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No job posts waiting for approval.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, int i) => AdminJobApprovalCard(job: jobs[i]),
          );
        },
      ),
    );
  }
}
