import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/category_assets.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/rides/presentation/providers/rides_providers.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_map_markers.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_map_support.dart';

enum _CategoryAction { food, groceries, ride, jobs }

class _CategoryItem {
  const _CategoryItem({
    required this.assetPath,
    required this.action,
    required this.name,
  });

  final String name;
  final String assetPath;
  final _CategoryAction action;
}

const List<_CategoryItem> _kCategories = <_CategoryItem>[
  _CategoryItem(
    name: 'Food',
    assetPath: CategoryAssets.food,
    action: _CategoryAction.food,
  ),
  _CategoryItem(
    name: 'Groceries',
    assetPath: CategoryAssets.groceries,
    action: _CategoryAction.groceries,
  ),
  _CategoryItem(
    name: 'Rides',
    assetPath: CategoryAssets.ride,
    action: _CategoryAction.ride,
  ),
  _CategoryItem(
    name: 'Jobs',
    assetPath: CategoryAssets.jobs,
    action: _CategoryAction.jobs,
  ),
];

void _onCategoryTap(BuildContext context, WidgetRef ref, _CategoryItem item) {
  switch (item.action) {
    case _CategoryAction.food:
      context.push(AppRoutes.customerFood);
    case _CategoryAction.groceries:
      context.push(AppRoutes.customerGrocery);
    case _CategoryAction.ride:
      ref.read(activeRideTripProvider);
      if (isRidesMapSupported()) {
        RidesMapMarkers.ensureLoaded();
      }
      context.push(AppRoutes.customerRides);
    case _CategoryAction.jobs:
      ref.read(activeJobsStreamProvider);
      ref.read(savedJobIdsProvider);
      ref.read(myJobApplicationsStreamProvider);
      context.push(AppRoutes.customerJobs);
  }
}

/// Equal service tiles — shared gray icon background, no selected state.
class HomeCategoryRail extends ConsumerWidget {
  const HomeCategoryRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeSectionEntrance(
      delay: const Duration(milliseconds: 60),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double gap = 10;
          final double cardWidth =
              (constraints.maxWidth - gap * (_kCategories.length - 1)) /
                  _kCategories.length;

          return Row(
            children: <Widget>[
              for (int i = 0; i < _kCategories.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: gap),
                SizedBox(
                  width: cardWidth,
                  child: _ServiceTile(
                    item: _kCategories[i],
                    onTap: () => _onCategoryTap(context, ref, _kCategories[i]),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.item,
    required this.onTap,
  });

  final _CategoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MndPressable(
      onTap: onTap,
      scale: 0.96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.homeMutedFill,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                item.assetPath,
                fit: BoxFit.contain,
                semanticLabel: item.name,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: -0.1,
                ),
          ),
        ],
      ),
    );
  }
}
