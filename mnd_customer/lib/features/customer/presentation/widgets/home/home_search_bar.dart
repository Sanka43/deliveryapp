import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/home_recent_searches_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';

class HomeSearchBar extends ConsumerWidget {
  const HomeSearchBar({
    required this.scrollOffset,
    super.key,
  });

  final double scrollOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> recents = ref.watch(homeRecentSearchesProvider);
    final double parallax = (scrollOffset * 0.08).clamp(0.0, 8.0);

    return Transform.translate(
      offset: Offset(0, -parallax),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MndPressable(
            onTap: () => openCustomerSearch(context),
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
                      'Search foods, groceries, pharmacies…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                  _IconAction(
                    icon: Icons.mic_rounded,
                    onTap: () => openCustomerSearch(context),
                  ),
                  const SizedBox(width: 4),
                  _IconAction(
                    icon: Icons.tune_rounded,
                    onTap: () => openCustomerSearch(context),
                  ),
                ],
              ),
            ),
          ),
          if (recents.isNotEmpty || kHomeTrendingSearches.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  if (recents.isNotEmpty) ...<Widget>[
                    _ChipLabel(text: 'Recent'),
                    const SizedBox(width: 6),
                    for (final String term in recents)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _SearchChip(
                          label: term,
                          onTap: () => navigateToSearchWithQuery(ref, context, term),
                        ),
                      ),
                    const SizedBox(width: 6),
                  ],
                  _ChipLabel(text: 'Trending'),
                  const SizedBox(width: 6),
                  for (final String term in kHomeTrendingSearches)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _SearchChip(
                        label: term,
                        highlighted: true,
                        onTap: () => navigateToSearchWithQuery(ref, context, term),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandPrimary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: AppColors.brandPrimary),
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SearchChip extends StatelessWidget {
  const _SearchChip({
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted
          ? AppColors.brandPrimary.withValues(alpha: 0.1)
          : AppColors.homeMutedFill,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: highlighted ? AppColors.brandPrimary : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
