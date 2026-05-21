import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/utils/product_price_display.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/home_recent_searches_provider.dart';

/// Horizontal product tile — white card, image on top, title, subtitle, price + add.
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
    this.isAvailable = true,
    this.premium = false,
    super.key,
  });

  static const double premiumWidth = 188;
  static const double standardWidth = 170;

  /// Fixed height for text + price row (with subtitle) — avoids grid overflow.
  static const double contentHeightWithSubtitle = 108;
  static const double contentHeightNoSubtitle = 84;

  /// Suggested grid aspect ratio for a 2-column product grid.
  static const double gridChildAspectRatio = 0.62;

  /// Height for horizontal home lists (square image + content).
  static double get homeListHeight =>
      premiumWidth + contentHeightWithSubtitle;

  final String name;
  final String imageUrl;
  final String priceLabel;
  final String? storeName;
  final String? description;
  final String? etaLabel;
  final VoidCallback onAddToCart;
  final bool isAvailable;
  final String? productKey;
  final bool premium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? subtitle = description ?? storeName;
    final bool hasSubtitle = subtitle != null && subtitle.isNotEmpty;
    final String key = productKey ?? name;
    final bool isFavorite =
        premium && ref.watch(productFavoritesProvider).contains(key);
    final double contentHeight =
        hasSubtitle ? contentHeightWithSubtitle : contentHeightNoSubtitle;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = premium
            ? premiumWidth
            : (constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : standardWidth);

        final bool boundedHeight = constraints.hasBoundedHeight;
        // Grid cells: fit image + fixed content inside max height. Home/premium: strict 1:1.
        final double imageSide = premium
            ? width
            : boundedHeight
                ? (constraints.maxHeight - contentHeight).clamp(0.0, width)
                : width;

        final Widget imageStack = Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(
              color: AppColors.homeMutedFill,
              child: SizedBox.expand(
                child: isAvailable
                    ? MndNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                      )
                    : ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.white.withValues(alpha: 0.5),
                          BlendMode.srcATop,
                        ),
                        child: MndNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            if (premium)
              Positioned(
                top: 6,
                right: 6,
                child: _FavoriteIcon(
                  isFavorite: isFavorite,
                  onTap: () =>
                      ref.read(productFavoritesProvider.notifier).toggle(key),
                ),
              ),
            if (!isAvailable)
              const Positioned(
                left: 8,
                top: 8,
                child: _AvailabilityBadge(isAvailable: false),
              ),
          ],
        );

        return SizedBox(
          width: premium ? width : double.infinity,
          height: boundedHeight ? constraints.maxHeight : null,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
              boxShadow: AppColors.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: width,
                  height: imageSide,
                  child: imageStack,
                ),
                SizedBox(
                  height: contentHeight,
                  child: _ProductCardContent(
                    name: name,
                    subtitle: hasSubtitle ? subtitle : null,
                    etaLabel: etaLabel,
                    priceLabel: priceLabel,
                    isAvailable: isAvailable,
                    onAddToCart: onAddToCart,
                  ),
                ),
              ],
            ),
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
    this.subtitle,
    this.etaLabel,
  });

  final String name;
  final String? subtitle;
  final String? etaLabel;
  final String priceLabel;
  final bool isAvailable;
  final VoidCallback onAddToCart;

  static bool _showEta(String? eta) {
    if (eta == null) {
      return false;
    }
    final String trimmed = eta.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return trimmed.toLowerCase() != 'n/a';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.homeMutedFill.withValues(alpha: 0.9),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.25,
                          height: 1.1,
                        ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_showEta(etaLabel))
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _EtaChip(label: etaLabel!.trim()),
                  ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: _ProductPriceText(priceLabel: priceLabel),
                ),
                const SizedBox(width: 8),
                _CircularAddButton(
                  onPressed: isAvailable ? onAddToCart : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPriceText extends StatelessWidget {
  const _ProductPriceText({required this.priceLabel});

  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    final ProductPriceParts parts = ProductPriceDisplay.parse(priceLabel);

    final TextStyle prefixStyle = GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
      letterSpacing: -0.1,
      height: 1.1,
    );

    final TextStyle amountStyle = GoogleFonts.plusJakartaSans(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      letterSpacing: -0.35,
      height: 1.1,
    );

    final String prefixLine = parts.showFrom ? 'From Rs' : 'Rs';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          prefixLine,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: prefixStyle,
        ),
        const SizedBox(height: 2),
        Text(
          parts.amount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: amountStyle,
        ),
      ],
    );
  }
}

class _EtaChip extends StatelessWidget {
  const _EtaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.schedule_rounded,
            size: 11,
            color: AppColors.brandPrimary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.brandPrimary,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteIcon extends StatelessWidget {
  const _FavoriteIcon({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MndPressable(
      onTap: onTap,
      scale: 0.9,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey<bool>(isFavorite),
            size: 21,
            color: isFavorite
                ? const Color(0xFFE53935)
                : const Color(0xFFE53935).withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _CircularAddButton extends StatelessWidget {
  const _CircularAddButton({required this.onPressed});

  final VoidCallback? onPressed;

  static const double _size = 38;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    return Material(
      elevation: enabled ? 2 : 0,
      shadowColor: AppColors.brandPrimary.withValues(alpha: 0.35),
      color: enabled ? AppColors.brandPrimary : AppColors.homeMutedFill,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _size,
          height: _size,
          child: Icon(
            Icons.add_rounded,
            color: enabled ? Colors.white : AppColors.textSecondary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.isAvailable});

  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable ? AppColors.success : AppColors.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isAvailable ? 'In Stock' : 'Out of Stock',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
