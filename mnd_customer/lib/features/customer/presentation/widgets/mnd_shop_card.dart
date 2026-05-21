import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';

/// Nearby shop tile — hero image, compact metadata, no delivery promo badges.
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

  static bool _showDeliveryFee(String fee) {
    final String normalized = fee.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return !(normalized.contains('0') && normalized.contains('lkr'));
  }

  @override
  Widget build(BuildContext context) {
    final bool showEta = _showEta(store.eta);
    final bool showDeliveryFee = _showDeliveryFee(store.deliveryFee);

    return MndPressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
          border: Border.all(
            color: AppColors.homeMutedFill.withValues(alpha: 0.85),
          ),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 152,
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
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _OpenBadge(),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.homeMutedFill.withValues(alpha: 0.9),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            store.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(label: store.tag),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        _MetaChip(
                          icon: Icons.star_rounded,
                          label: store.rating.toStringAsFixed(1),
                          iconColor: const Color(0xFFFBBF24),
                          background: const Color(0x14FBBF24),
                          foreground: AppColors.textPrimary,
                        ),
                        if (showEta)
                          _MetaChip(
                            icon: Icons.schedule_rounded,
                            label: store.eta.trim(),
                            iconColor: AppColors.brandPrimary,
                            background: AppColors.brandPrimary.withValues(alpha: 0.08),
                            foreground: AppColors.brandPrimary,
                          ),
                        if (showDeliveryFee)
                          _MetaChip(
                            icon: Icons.delivery_dining_rounded,
                            label: store.deliveryFee,
                            iconColor: AppColors.textSecondary,
                            background: AppColors.homeMutedFill,
                            foreground: AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Open',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.homeMutedFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          height: 1.0,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: foreground,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
