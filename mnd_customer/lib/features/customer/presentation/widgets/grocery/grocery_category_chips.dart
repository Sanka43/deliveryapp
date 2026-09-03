import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/grocery_catalog_provider.dart';

class GroceryCategoryChips extends ConsumerWidget {
  const GroceryCategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<String>> labelsAsync =
        ref.watch(groceryCategoryLabelsProvider);
    final String? selected = ref.watch(selectedGroceryCategoryProvider);

    return HomeSectionEntrance(
      delay: Duration.zero,
      child: labelsAsync.when(
        loading: () => const SizedBox(
          height: 36,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => _ChipRow(
          labels: kGroceryCategoryFallbackLabels,
          selected: selected,
          onSelected: (String label) {
            ref.read(selectedGroceryCategoryProvider.notifier).state = label;
          },
        ),
        data: (List<String> labels) => _ChipRow(
          labels: labels,
          selected: selected,
          onSelected: (String label) {
            ref.read(selectedGroceryCategoryProvider.notifier).state = label;
          },
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) {
          final String label = labels[index];
          final bool isSelected = (selected ?? 'All') == label;
          return Material(
            color: isSelected ? AppColors.brandPrimary : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
            child: InkWell(
              onTap: () => onSelected(label),
              borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: AppColors.textPrimary.withValues(alpha: 0.08),
                        ),
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
