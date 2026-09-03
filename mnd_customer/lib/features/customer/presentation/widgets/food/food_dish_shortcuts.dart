import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/food_catalog_provider.dart';

class _DishShortcut {
  const _DishShortcut(this.label, this.imageAsset);

  final String label;
  final String imageAsset;
}

const List<_DishShortcut> _kDishShortcuts = <_DishShortcut>[
  _DishShortcut('Rice and curry', 'assets/images/dishes/rice_curry.png'),
  _DishShortcut('Fried rice', 'assets/images/dishes/fried_rice.png'),
  _DishShortcut('Kottu', 'assets/images/dishes/kottu.png'),
  _DishShortcut('Pasta', 'assets/images/dishes/pasta.png'),
  _DishShortcut('Noodles', 'assets/images/dishes/noodles.png'),
  _DishShortcut('Beverages', 'assets/images/dishes/beverages.png'),
  _DishShortcut('Desert', 'assets/images/dishes/desert.png'),
  _DishShortcut('Shot eats', 'assets/images/dishes/shot_eats.png'),
];

const int _kColumns = 4;
const double _kRowGap = AppSpacing.sm;
const double _kColumnGap = 10;

/// Quick dish-type shortcuts shown under the "Popular" header — a 4-column,
/// 2-row grid. Tapping one sets [selectedFoodCategoryProvider], reusing the
/// same filter the shop-type chip row above writes to.
class FoodDishShortcuts extends ConsumerWidget {
  const FoodDishShortcuts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? selected = ref.watch(selectedFoodCategoryProvider);

    return HomeSectionEntrance(
      delay: Duration.zero,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double tileWidth =
              (constraints.maxWidth - _kColumnGap * (_kColumns - 1)) /
                  _kColumns;

          Widget buildRow(int start) {
            return Row(
              children: <Widget>[
                for (int i = start; i < start + _kColumns; i++) ...<Widget>[
                  if (i > start) const SizedBox(width: _kColumnGap),
                  SizedBox(
                    width: tileWidth,
                    child: _ShortcutTile(
                      label: _kDishShortcuts[i].label,
                      imageAsset: _kDishShortcuts[i].imageAsset,
                      selected: selected == _kDishShortcuts[i].label,
                      onTap: () {
                        final String label = _kDishShortcuts[i].label;
                        ref.read(selectedFoodCategoryProvider.notifier).state =
                            selected == label ? 'All' : label;
                      },
                    ),
                  ),
                ],
              ],
            );
          }

          return Column(
            children: <Widget>[
              buildRow(0),
              const SizedBox(height: _kRowGap),
              buildRow(_kColumns),
            ],
          );
        },
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.label,
    required this.imageAsset,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String imageAsset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MndPressable(
      onTap: onTap,
      scale: 0.96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.homeMutedFill,
              border: selected
                  ? Border.all(color: AppColors.brandPrimary, width: 2)
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              cacheWidth: 104,
              cacheHeight: 104,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                  letterSpacing: -0.1,
                  height: 1.15,
                ),
          ),
        ],
      ),
    );
  }
}
