import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_card.dart';

class JobsHorizontalSection extends StatelessWidget {
  const JobsHorizontalSection({
    required this.title,
    required this.jobs,
    this.icon,
    this.actionLabel,
    this.onActionTap,
    super.key,
  });

  final String title;
  final List<JobListing> jobs;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  static const Map<String, IconData> _sectionIcons = <String, IconData>{
    'Trending': Icons.trending_up_rounded,
    'Urgent hiring': Icons.bolt_rounded,
    'Latest': Icons.schedule_rounded,
    'Recommended': Icons.recommend_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return const SizedBox.shrink();
    }

    final IconData sectionIcon = icon ?? _sectionIcons[title] ?? Icons.work_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                boxShadow: AppColors.cardShadow,
              ),
              child: Icon(sectionIcon, size: 18, color: AppColors.brandPrimary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (actionLabel != null && onActionTap != null)
              TextButton(
                onPressed: onActionTap,
                child: Text(actionLabel!),
              ),
          ],
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
