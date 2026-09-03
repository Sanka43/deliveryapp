import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';

/// Nearby shop card — matches reference: image, Open, name, rating, type · ETA, address.
class MndShopCard extends StatelessWidget {
  const MndShopCard({
    required this.store,
    required this.onTap,
    super.key,
  });

  final SearchStore store;
  final VoidCallback onTap;

  static bool _showEta(String eta) {
    final String trimmed = eta.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return trimmed.toLowerCase() != 'n/a';
  }

  String get _typeLabel {
    final String tag = store.tag.trim();
    if (tag.isNotEmpty && tag.toLowerCase() != 'general') {
      return tag;
    }
    final String category = store.category.trim();
    if (category.isNotEmpty) {
      return category;
    }
    return 'Shop';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool showEta = _showEta(store.eta);
    final String address = store.address.trim();
    final bool showRating = store.rating > 0;

    return MndPressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
          boxShadow: AppColors.shadowElevated,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 168,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(
                    color: AppColors.homeMutedFill,
                    child: MndNetworkImage(
                      imageUrl: store.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _StatusBadge(isOpen: store.isOpen),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          store.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (showRating) ...<Widget>[
                        const SizedBox(width: 10),
                        _RatingPill(rating: store.rating),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          _typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (showEta) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '·',
                            style: text.bodyLarge?.copyWith(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.55,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          store.eta.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (address.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact horizontal shop row for dense lists (home, food, All Shops).
class MndShopCardCompact extends StatelessWidget {
  const MndShopCardCompact({
    required this.store,
    required this.onTap,
    super.key,
  });

  final SearchStore store;
  final VoidCallback onTap;

  /// Fixed thumb size for every compact shop row (card height stays constant).
  static const double thumbWidth = 112;
  static const double thumbHeight = 76;
  static const double cardHeight = 96;

  String get _typeLabel {
    final String tag = store.tag.trim();
    if (tag.isNotEmpty && tag.toLowerCase() != 'general') {
      return tag;
    }
    final String category = store.category.trim();
    if (category.isNotEmpty) {
      return category;
    }
    return 'Shop';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool showEta = MndShopCard._showEta(store.eta);
    final bool showRating = store.rating > 0;
    final bool isTopRated = store.rating >= 4.5;
    final String address = store.address.trim();

    return MndPressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
          boxShadow: AppColors.shadowElevated,
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: thumbWidth,
                height: thumbHeight,
                child: ColoredBox(
                  color: AppColors.homeMutedFill,
                  child: MndNetworkImage(
                    imageUrl: store.imageUrl,
                    width: thumbWidth,
                    height: thumbHeight,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                store.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            if (isTopRated) ...<Widget>[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 15,
                                color: AppColors.brandPrimary,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(isOpen: store.isOpen, compact: true),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: <Widget>[
                      if (showRating) ...<Widget>[
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          store.rating.toStringAsFixed(1),
                          style: text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.0,
                          ),
                        ),
                        _CompactMetaDot(style: text.labelMedium),
                      ],
                      Flexible(
                        child: Text(
                          _typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                            height: 1.1,
                          ),
                        ),
                      ),
                      if (showEta) ...<Widget>[
                        _CompactMetaDot(style: text.labelMedium),
                        Text(
                          store.eta.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (address.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 5),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.85,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMetaDot extends StatelessWidget {
  const _CompactMetaDot({required this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: style?.copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.55),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.isOpen,
    this.compact = false,
  });

  final bool isOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color bg = isOpen ? AppColors.success : AppColors.error;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        boxShadow: compact
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: bg.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Text(
        isOpen ? 'Open' : 'Closed',
        style: (compact
                ? Theme.of(context).textTheme.labelSmall
                : Theme.of(context).textTheme.labelLarge)
            ?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
            ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.star_rounded,
            size: 16,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.0,
                ),
          ),
        ],
      ),
    );
  }
}
