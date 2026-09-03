import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_card.dart';

class JobsHorizontalSection extends StatelessWidget {
  const JobsHorizontalSection({
    required this.title,
    required this.jobs,
    this.actionLabel,
    this.onActionTap,
    super.key,
  });

  final String title;
  final List<JobListing> jobs;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MndSectionHeader(
          title: title,
          actionLabel: actionLabel,
          onActionTap: onActionTap,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: JobCard.compactHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              return JobCard(job: jobs[index], compact: true);
            },
          ),
        ),
      ],
    );
  }
}
