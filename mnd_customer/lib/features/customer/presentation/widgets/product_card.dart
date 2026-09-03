import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/utils/product_price_display.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/home_recent_searches_provider.dart';

/// Product tile for home / food / grocery / favorites.
class ProductCard extends ConsumerWidget {
  const ProductCard({
    required this.name,
    required this.imageUrl,
    required this.priceLabel,
    required this.onAddToCart,
    this.productKey,
    this.storeName,
    this.description,
    this.etaLabel,
    this.rating,
    this.isAvailable = true,
    this.premium = false,
    this.showAddToCartButton = true,
    this.onTap,
    super.key,
  });

  static const double premiumWidth = 164;
  static const double standardWidth = 160;

  /// Tall food-photo plane + compact text block.
  static const double premiumImageHeight = 148;

  static const double contentHeightWithSubtitle = 80;
  static const double contentHeightNoSubtitle = 64;

  /// Shorter content block used when [showAddToCartButton] is false — no
  /// button row means less room is needed, so the subtitle-to-price gap
  /// doesn't stretch to fill the taller, button-sized box.
  static const double contentHeightWithSubtitleCompact = 68;
  static const double contentHeightNoSubtitleCompact = 54;

  static const double gridChildAspectRatio = 0.64;

  /// 8px top image inset is included in the card stack.
  static double get homeListHeight =>
      8 + premiumImageHeight + contentHeightWithSubtitle;

  /// Matches [homeListHeight] but for cards rendered with
  /// `showAddToCartButton: false`.
  static double get homeListHeightCompact =>
      8 + premiumImageHeight + contentHeightWithSubtitleCompact;

  final String name;
  final String imageUrl;
  final String priceLabel;
  final String? storeName;
  final String? description;
  final String? etaLabel;
  final double? rating;
  final VoidCallback onAddToCart;
  final bool isAvailable;
  final String? productKey;
  final bool premium;
  final bool showAddToCartButton;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? shopLabel = () {
      final String? store = storeName?.trim();
      if (store != null && store.isNotEmpty) {
        return store;
      }
      final String? desc = description?.trim();
      if (desc != null && desc.isNotEmpty) {
        return desc;
      }
      return null;
    }();
    final String? eta = () {
      final String? raw = etaLabel?.trim();
      if (raw == null || raw.isEmpty) {
        return null;
      }
      if (raw.toLowerCase() == 'n/a') {
        return null;
      }
      return raw;
    }();
    final bool hasMeta = shopLabel != null || eta != null;
    final double contentHeight = showAddToCartButton
        ? (hasMeta ? contentHeightWithSubtitle : contentHeightNoSubtitle)
        : (hasMeta
            ? contentHeightWithSubtitleCompact
            : contentHeightNoSubtitleCompact);
    final String favKey = productKey ?? name;
    final bool isFavorite =
        ref.watch(productFavoritesProvider).contains(favKey);
    final bool showRating = rating != null && rating! > 0;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = premium
            ? premiumWidth
            : (constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : standardWidth);

        final bool boundedHeight = constraints.hasBoundedHeight;
        final double imageSide = premium
            ? premiumImageHeight
            : boundedHeight
                ? (constraints.maxHeight - contentHeight - 8)
                    .clamp(96.0, width)
                : width * 0.92;

        final Widget card = DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE8EEF6),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: SizedBox(
                    height: imageSide,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ColoredBox(
                            color: AppColors.homeMutedFill,
                            child: isAvailable
                                ? MndNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                  )
                                : ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      Colors.white.withValues(alpha: 0.55),
                                      BlendMode.srcATop,
                                    ),
                                    child: MndNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _FavoriteButton(
                            isFavorite: isFavorite,
                            onTap: () => ref
                                .read(productFavoritesProvider.notifier)
                                .toggle(favKey),
                          ),
                        ),
                        if (!isAvailable)
                          const Positioned(
                            left: 8,
                            top: 8,
                            child: _AvailabilityBadge(),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: contentHeight,
                  child: _ProductCardContent(
                    shopName: shopLabel,
                    etaLabel: eta,
                    name: name,
                    priceLabel: priceLabel,
                    rating: showRating ? rating : null,
                    isAvailable: isAvailable,
                    onAddToCart: onAddToCart,
                    showAddToCartButton: showAddToCartButton,
                  ),
                ),
              ],
            ),
          ),
        );

        return SizedBox(
          width: premium ? width : double.infinity,
          height: boundedHeight
              ? constraints.maxHeight
              : (premium ? 8 + imageSide + contentHeight : null),
          child: onTap == null
              ? card
              : MndPressable(
                  onTap: onTap,
                  scale: 0.98,
                  child: card,
                ),
        );
      },
    );
  }
}

class _ProductCardContent extends StatelessWidget {
  const _ProductCardContent({
    required this.name,
    required this.priceLabel,
    required this.isAvailable,
    required this.onAddToCart,
    required this.showAddToCartButton,
    this.shopName,
    this.etaLabel,
    this.rating,
  });

  final String? shopName;
  final String? etaLabel;
  final String name;
  final String priceLabel;
  final double? rating;
  final bool isAvailable;
  final VoidCallback onAddToCart;
  final bool showAddToCartButton;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool hasShop = shopName != null;
    final bool hasEta = etaLabel != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(
              fontSize: (text.titleSmall?.fontSize ?? 14) + 1,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
              height: 1.15,
            ),
          ),
          if (hasShop || hasEta) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              <String>[
                if (hasShop) shopName!,
                if (hasEta) etaLabel!,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.1,
              ),
            ),
          ],
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (rating != null) ...<Widget>[
                Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                const SizedBox(width: 2),
                Text(
                  rating!.toStringAsFixed(1),
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: showAddToCartButton
                    ? _PriceLabel(priceLabel: priceLabel, text: text)
                    : Align(
                        alignment: Alignment.centerRight,
                        child: _PriceLabel(priceLabel: priceLabel, text: text),
                      ),
              ),
              if (showAddToCartButton) ...<Widget>[
                const SizedBox(width: 8),
                _AddToCartButton(
                  onPressed: isAvailable ? onAddToCart : null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Renders `priceLabel` with a smaller, muted "From" prefix (when present)
/// ahead of the full-size price amount.
class _PriceLabel extends StatelessWidget {
  const _PriceLabel({required this.priceLabel, required this.text});

  final String priceLabel;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final ProductPriceParts parts = ProductPriceDisplay.parse(priceLabel);
    final TextStyle? amountStyle = text.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      letterSpacing: 0,
      height: 1.0,
    );

    if (!parts.showFrom) {
      return Text(
        priceLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: amountStyle,
      );
    }

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: 'From ',
            style: text.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withValues(alpha: 0.75),
              height: 1.0,
            ),
          ),
          TextSpan(text: 'Rs ${parts.amount}', style: amountStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.onTap,
  });

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MndPressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 15,
          color: isFavorite ? const Color(0xFFE53935) : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _AddToCartButton extends StatelessWidget {
  const _AddToCartButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    return MndPressable(
      onTap: onPressed,
      scale: 0.9,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? AppColors.brandPrimary : AppColors.homeMutedFill,
          shape: BoxShape.circle,
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.add_rounded,
          size: 22,
          color: enabled ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Out of stock',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
            ),
      ),
    );
  }
}
