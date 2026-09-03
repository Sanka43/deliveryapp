import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/features/jobs/domain/job_constants.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';

class JobsCategoryChips extends ConsumerWidget {
  const JobsCategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final JobsFilterState filter = ref.watch(jobsFilterProvider);
    final String? selected = filter.category;

    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusLg,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
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
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            );
          },
        ),
      ),
    );
  }
}
