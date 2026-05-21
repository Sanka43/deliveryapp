import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/jobs/domain/job_constants.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';

class JobsCategoryChips extends ConsumerWidget {
  const JobsCategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JobsFilterState filter = ref.watch(jobsFilterProvider);
    final String? selected = filter.category;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: AppColors.cardShadow,
      ),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: JobConstants.quickCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (BuildContext context, int index) {
            final String label = JobConstants.quickCategories[index];
            final bool isSelected =
                selected?.toLowerCase() == label.toLowerCase();
            return FilterChip(
              label: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (bool _) {
                ref.read(jobsFilterProvider.notifier).state = isSelected
                    ? filter.copyWith(clearCategory: true)
                    : filter.copyWith(category: label);
              },
              backgroundColor: AppColors.homeMutedFill,
              selectedColor: AppColors.brandPrimary,
              side: BorderSide(
                color: isSelected
                    ? AppColors.brandPrimary
                    : Colors.black.withValues(alpha: 0.06),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            );
          },
        ),
      ),
    );
  }
}
