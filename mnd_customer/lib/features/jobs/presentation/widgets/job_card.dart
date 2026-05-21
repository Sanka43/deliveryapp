import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_booked_badge.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_quick_apply_sheet.dart';

/// Job listing card — full white surface (compact rails + feed list).
class JobCard extends ConsumerWidget {
  const JobCard({
    required this.job,
    this.compact = false,
    super.key,
  });

  final JobListing job;
  final bool compact;

  static const double compactWidth = 272;
  static const double compactHeight = 228;

  static BoxDecoration get _whiteDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: AppColors.cardShadow,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Set<String>> savedIds = ref.watch(savedJobIdsProvider);
    final bool saved = savedIds.valueOrNull?.contains(job.id) ?? false;
    final bool isBooked = ref.watch(isJobBookedForMeProvider(job.id));
    final bool hasApplied = ref.watch(hasAppliedToJobLiveProvider(job.id));

    return MndPressable(
      onTap: () => context.push('${AppRoutes.customerJobDetail}/${job.id}'),
      scale: 0.98,
      child: compact
          ? _CompactJobCard(
              job: job,
              saved: saved,
              isBooked: isBooked,
              hasApplied: hasApplied,
            )
          : _FullJobCard(
              job: job,
              saved: saved,
              isBooked: isBooked,
              hasApplied: hasApplied,
            ),
    );
  }
}

class _CompactJobCard extends ConsumerWidget {
  const _CompactJobCard({
    required this.job,
    required this.saved,
    required this.isBooked,
    required this.hasApplied,
  });

  final JobListing job;
  final bool saved;
  final bool isBooked;
  final bool hasApplied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: JobCard.compactWidth,
      height: JobCard.compactHeight,
      clipBehavior: Clip.antiAlias,
      decoration: JobCard._whiteDecoration,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _CompanyAvatar(job: job, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _JobTitleRow(job: job, fontSize: 14),
                      const SizedBox(height: 2),
                      Text(
                        job.companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle(11.5, AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (job.urgent) const _UrgentDot(),
                if (isBooked)
                  const JobBookedBadge.compact()
                else
                  _SaveIconButton(
                    saved: saved,
                    onTap: () => _toggleSave(context, ref),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _SalaryLabel(salary: job.salary, compact: true),
            const SizedBox(height: 8),
            Expanded(
              child: _MetaChipRow(job: job, isBooked: isBooked, dense: true),
            ),
            Row(
              children: <Widget>[
                Text(
                  job.postedAgo,
                  style: _bodyStyle(10.5, AppColors.textSecondary),
                ),
                const Spacer(),
                _QuickApplyChip(
                  enabled: !hasApplied && !isBooked,
                  label: hasApplied ? 'Applied' : 'Apply',
                  onTap: () => showJobQuickApplySheet(context, ref, job),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSave(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(jobsRepositoryProvider).toggleSaveJob(job.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

class _FullJobCard extends ConsumerWidget {
  const _FullJobCard({
    required this.job,
    required this.saved,
    required this.isBooked,
    required this.hasApplied,
  });

  final JobListing job;
  final bool saved;
  final bool isBooked;
  final bool hasApplied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hasBanner =
        job.imageUrl != null && job.imageUrl!.trim().isNotEmpty;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: JobCard._whiteDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (hasBanner) _JobBanner(imageUrl: job.imageUrl!),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _CompanyAvatar(job: job, size: 50),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _JobTitleRow(job: job, fontSize: 16),
                          const SizedBox(height: 3),
                          Text(
                            job.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _bodyStyle(13, AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (isBooked)
                      const JobBookedBadge.compact()
                    else
                      _SaveIconButton(
                        saved: saved,
                        onTap: () => _toggleSave(context, ref),
                      ),
                  ],
                ),
                if (job.urgent) ...<Widget>[
                  const SizedBox(height: 10),
                  const _UrgentBanner(),
                ],
                const SizedBox(height: 12),
                _SalaryLabel(salary: job.salary),
                const SizedBox(height: 12),
                _MetaChipRow(job: job, isBooked: isBooked),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Text(
                      job.postedAgo,
                      style: _bodyStyle(12, AppColors.textSecondary),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.push(
                        '${AppRoutes.customerJobDetail}/${job.id}',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brandPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Text(
                        'Details',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: hasApplied || isBooked
                          ? null
                          : () => showJobQuickApplySheet(context, ref, job),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        disabledBackgroundColor: AppColors.homeMutedFill,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isBooked
                            ? 'Booked'
                            : hasApplied
                                ? 'Applied'
                                : 'Quick apply',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSave(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(jobsRepositoryProvider).toggleSaveJob(job.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

class _UrgentDot extends StatelessWidget {
  const _UrgentDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.offerOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.bolt_rounded,
        size: 14,
        color: AppColors.offerOrange,
      ),
    );
  }
}

class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.offerOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.bolt_rounded, size: 16, color: AppColors.offerOrange),
          const SizedBox(width: 6),
          Text(
            'Urgent hiring',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.offerOrange,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobBanner extends StatelessWidget {
  const _JobBanner({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: MndNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
    );
  }
}

class _CompanyAvatar extends StatelessWidget {
  const _CompanyAvatar({required this.job, required this.size});

  final JobListing job;
  final double size;

  String get _initials {
    final List<String> parts = job.companyName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    return parts.map((String p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final String? logo = job.logoUrl?.trim();
    final bool hasLogo = logo != null && logo.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.homeMutedFill,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? MndNetworkImage(imageUrl: logo, fit: BoxFit.cover)
          : Center(
              child: Text(
                _initials,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
    );
  }
}

class _JobTitleRow extends StatelessWidget {
  const _JobTitleRow({required this.job, required this.fontSize});

  final JobListing job;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            job.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.35,
              height: 1.15,
            ),
          ),
        ),
        if (job.verified) ...<Widget>[
          const SizedBox(width: 4),
          Icon(
            Icons.verified_rounded,
            size: fontSize + 2,
            color: AppColors.brandPrimary,
          ),
        ],
      ],
    );
  }
}

class _SalaryLabel extends StatelessWidget {
  const _SalaryLabel({required this.salary, this.compact = false});

  final String salary;
  final bool compact;

  static String _formatSalary(String raw) {
    final String t = raw.trim();
    if (t.isEmpty) {
      return 'Negotiable';
    }
    if (RegExp(r'^[0-9.,]+$').hasMatch(t.replaceAll(' ', ''))) {
      return 'LKR $t';
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          Icons.payments_outlined,
          size: compact ? 16 : 18,
          color: AppColors.brandPrimary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _formatSalary(salary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaChipRow extends StatelessWidget {
  const _MetaChipRow({
    required this.job,
    this.isBooked = false,
    this.dense = false,
  });

  final JobListing job;
  final bool isBooked;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: dense ? 5 : 6,
      runSpacing: dense ? 5 : 6,
      children: <Widget>[
        if (isBooked)
          const _InfoChip(
            icon: JobBookedBadge.bookedIcon,
            label: 'Booked',
            tint: AppColors.success,
            filled: true,
          ),
        _InfoChip(
          icon: job.remote ? Icons.wifi_rounded : Icons.location_on_outlined,
          label: job.remote ? 'Remote' : job.location,
          tint: job.remote ? AppColors.accentPurple : AppColors.brandPrimary,
        ),
        _InfoChip(
          icon: Icons.work_outline_rounded,
          label: job.type,
          tint: AppColors.textSecondary,
        ),
        if (job.availableLaborCount > 1)
          _InfoChip(
            icon: Icons.groups_outlined,
            label: '${job.availableLaborCount} workers',
            tint: AppColors.brandPrimary,
          ),
        if (job.urgent && !dense)
          const _InfoChip(
            icon: Icons.bolt_rounded,
            label: 'Urgent',
            tint: AppColors.offerOrange,
            filled: true,
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.tint,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? tint.withValues(alpha: 0.1)
            : AppColors.homeMutedFill,
        borderRadius: BorderRadius.circular(8),
        border: filled
            ? Border.all(color: tint.withValues(alpha: 0.2))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: filled ? tint : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: filled ? tint : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveIconButton extends StatelessWidget {
  const _SaveIconButton({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: saved
          ? AppColors.brandPrimary.withValues(alpha: 0.1)
          : AppColors.homeMutedFill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
            size: 20,
            color: saved ? AppColors.brandPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _QuickApplyChip extends StatelessWidget {
  const _QuickApplyChip({
    required this.onTap,
    this.enabled = true,
    this.label = 'Apply',
  });

  final VoidCallback onTap;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.brandPrimary : AppColors.homeMutedFill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: enabled ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _bodyStyle(double size, Color color) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: FontWeight.w500,
    color: color,
  );
}
