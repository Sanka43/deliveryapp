import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';

class FoodPageSearchBar extends ConsumerWidget {
  const FoodPageSearchBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MndPressable(
      onTap: () => navigateToSearchWithQuery(ref, context, 'Food'),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.searchBarShadow,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.search_rounded,
              color: AppColors.brandPrimary.withValues(alpha: 0.85),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search food, restaurants, dishes…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
            Material(
              color: AppColors.brandPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => openCustomerSearch(context),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
