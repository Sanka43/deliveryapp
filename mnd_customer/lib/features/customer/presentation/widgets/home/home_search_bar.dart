import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';

/// Tappable search field that opens customer search.
class HomeSearchBar extends ConsumerWidget {
  const HomeSearchBar({
    this.scrollOffset = 0,
    super.key,
  });

  final double scrollOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MndPressable(
      onTap: () => openCustomerSearch(context),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.textSecondary.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search foods, restaurants...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
