import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_banners_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:shimmer/shimmer.dart';

class HomeHeroCarousel extends ConsumerStatefulWidget {
  const HomeHeroCarousel({super.key});

  @override
  ConsumerState<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends ConsumerState<HomeHeroCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CustomerBanner>> bannersState =
        ref.watch(customerBannersProvider);

    return HomeSectionEntrance(
      delay: const Duration(milliseconds: 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          bannersState.when(
            loading: () => const _BannerShimmer(),
            error: (Object error, _) => SizedBox(
              height: 190,
              child: Center(
                child: Text(
                  catalogLoadErrorMessage(error),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            data: (List<CustomerBanner> banners) {
              if (banners.isEmpty) {
                return SizedBox(
                  height: 190,
                  child: Center(
                    child: Text(
                      'No promotional banners yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                );
              }
              return Column(
                children: <Widget>[
                  CarouselSlider.builder(
                    itemCount: banners.length,
                    options: CarouselOptions(
                      height: 190,
                      viewportFraction: 0.88,
                      enlargeCenterPage: true,
                      enlargeFactor: 0.18,
                      autoPlay: banners.length > 1,
                      autoPlayInterval: const Duration(seconds: 5),
                      onPageChanged: (int index, _) =>
                          setState(() => _current = index),
                    ),
                    itemBuilder: (BuildContext context, int index, int _) {
                      return _HeroBannerCard(banner: banners[index]);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(banners.length, (int i) {
                      final bool active = i == _current;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: active ? AppColors.brandGradient : null,
                          color: active
                              ? null
                              : AppColors.textSecondary.withValues(alpha: 0.25),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroBannerCard extends StatelessWidget {
  const _HeroBannerCard({required this.banner});

  final CustomerBanner banner;

  @override
  Widget build(BuildContext context) {
    return MndPressable(
      onTap: () => openCustomerSearch(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
          gradient: LinearGradient(
            colors: <Color>[banner.startColor, banner.endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: AppColors.shadowElevated,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (banner.imageUrl != null)
              Opacity(
                opacity: 0.35,
                child: MndNetworkImage(
                  imageUrl: banner.imageUrl!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  showWatermarkOnError: false,
                ),
              ),
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                _iconForKey(banner.iconKey),
                size: 120,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    banner.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    banner.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Order now',
                      style: GoogleFonts.plusJakartaSans(
                        color: banner.startColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForKey(String key) {
    switch (key.toLowerCase().trim()) {
      case 'grocery':
        return Icons.local_grocery_store_rounded;
      case 'food':
        return Icons.fastfood_rounded;
      case 'offer':
      case 'flash':
        return Icons.local_offer_rounded;
      case 'pharmacy':
        return Icons.local_hospital_rounded;
      default:
        return Icons.delivery_dining_rounded;
    }
  }
}

class _BannerShimmer extends StatelessWidget {
  const _BannerShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.homeMutedFill,
      highlightColor: Colors.white,
      child: Container(
        height: 190,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.homeMutedFill,
          borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        ),
      ),
    );
  }
}
