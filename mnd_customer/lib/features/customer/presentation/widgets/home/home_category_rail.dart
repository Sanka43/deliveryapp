import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/category_assets.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';

enum _CategoryAction { food, groceries, ride, jobs }

class _CategoryItem {
  const _CategoryItem({
    required this.name,
    required this.assetPath,
    required this.action,
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

const List<String> _kCategoryAssetPaths = <String>[
  CategoryAssets.food,
  CategoryAssets.groceries,
  CategoryAssets.ride,
  CategoryAssets.jobs,
];

void _onCategoryTap(
  BuildContext context,
  WidgetRef ref,
  _CategoryItem item,
) {
  switch (item.action) {
    case _CategoryAction.food:
      context.push(AppRoutes.customerFood);
    case _CategoryAction.groceries:
      navigateToSearchWithQuery(ref, context, 'Groceries');
    case _CategoryAction.ride:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} — coming soon on MND.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    case _CategoryAction.jobs:
      context.push(AppRoutes.customerJobs);
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.item, required this.onTap});

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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.06),
                      blurRadius: 26,
                      offset: const Offset(0, 4),
                      spreadRadius: -6,
                    ),
                    BoxShadow(
                      color: AppColors.brandPrimary.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 2),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Image.asset(
                  item.assetPath,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    debugPrint('Category asset failed: ${item.assetPath} $error');
                    return Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                        size: 28,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.15,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Four core services: Food, Groceries, Ride, Jobs (single row).
class HomeCategoryRail extends ConsumerStatefulWidget {
  const HomeCategoryRail({super.key});

  @override
  ConsumerState<HomeCategoryRail> createState() => _HomeCategoryRailState();
}

class _HomeCategoryRailState extends ConsumerState<HomeCategoryRail> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final String path in _kCategoryAssetPaths) {
      precacheImage(AssetImage(path), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomeSectionEntrance(
      delay: const Duration(milliseconds: 100),
      child: Row(
        children: List<Widget>.generate(_kCategories.length, (int index) {
          final _CategoryItem item = _kCategories[index];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 5,
                right: index == _kCategories.length - 1 ? 0 : 5,
              ),
              child: _CategoryTile(
                item: item,
                onTap: () => _onCategoryTap(context, ref, item),
              ),
            ),
          );
        }),
      ),
    );
  }
}
