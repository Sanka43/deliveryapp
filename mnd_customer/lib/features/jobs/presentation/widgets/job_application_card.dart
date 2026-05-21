import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_application.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_booked_badge.dart';
import 'package:url_launcher/url_launcher.dart';

class JobApplicationCard extends StatelessWidget {
  const JobApplicationCard({
    required this.application,
    required this.showEmployerActions,
    this.onShortlist,
    this.onBook,
    this.onReject,
    this.canBook = true,
    super.key,
  });

  final JobApplication application;
  final bool showEmployerActions;
  final VoidCallback? onShortlist;
  final VoidCallback? onBook;
  final VoidCallback? onReject;
  final bool canBook;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
        side: BorderSide(color: AppColors.homeMutedFill),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.12),
                  child: Text(
                    _initials(application.applicantName),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        application.applicantName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        application.applicantPhone,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: application.status),
              ],
            ),
            if (!showEmployerActions &&
                (application.jobTitle.isNotEmpty ||
                    application.companyName.isNotEmpty)) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                application.jobTitle.isNotEmpty
                    ? application.jobTitle
                    : application.companyName,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
            if (application.bio != null && application.bio!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                application.bio!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                IconButton.outlined(
                  tooltip: 'Call',
                  onPressed: () => _launchTel(application.applicantPhone),
                  icon: const Icon(Icons.phone_rounded, size: 18),
                ),
                const SizedBox(width: 8),
                if (application.cvUrl != null && application.cvUrl!.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _launchUrl(application.cvUrl!),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('CV'),
                  ),
                const Spacer(),
                if (showEmployerActions &&
                    application.status != JobApplicationStatus.booked &&
                    onBook != null)
                  FilledButton(
                    onPressed: canBook ? onBook : null,
                    child: Text(canBook ? 'Book' : 'Slots full'),
                  ),
              ],
            ),
            if (showEmployerActions &&
                application.status != JobApplicationStatus.booked &&
                application.status != JobApplicationStatus.rejected) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onShortlist,
                      child: const Text('Shortlist'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return '?';
    }
    return parts.take(2).map((String p) => p[0].toUpperCase()).join();
  }

  Future<void> _launchTel(String phone) async {
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _launchUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg, String label}) style = switch (status) {
      JobApplicationStatus.booked => (
          bg: AppColors.success.withValues(alpha: 0.15),
          fg: AppColors.success,
          label: 'Booked',
        ),
      JobApplicationStatus.shortlisted => (
          bg: AppColors.brandPrimary.withValues(alpha: 0.12),
          fg: AppColors.brandPrimary,
          label: 'Shortlisted',
        ),
      JobApplicationStatus.rejected => (
          bg: AppColors.error.withValues(alpha: 0.12),
          fg: AppColors.error,
          label: 'Rejected',
        ),
      _ => (
          bg: AppColors.homeMutedFill,
          fg: AppColors.textSecondary,
          label: 'Applied',
        ),
    };

    final bool showIcon = status == JobApplicationStatus.booked;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showIcon) ...<Widget>[
            Icon(
              JobBookedBadge.bookedIcon,
              size: 14,
              color: style.fg,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            style.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: style.fg,
            ),
          ),
        ],
      ),
    );
  }
}
