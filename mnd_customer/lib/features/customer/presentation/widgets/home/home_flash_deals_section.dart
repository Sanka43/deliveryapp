import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_banners_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';

class HomeFlashDealsSection extends ConsumerWidget {
  const HomeFlashDealsSection({super.key});

  List<CustomerBanner> _flashBanners(List<CustomerBanner> all) {
    final List<CustomerBanner> flash = all
        .where(
          (CustomerBanner b) =>
              b.iconKey.toLowerCase() == 'flash' ||
              b.subtitle.toLowerCase().contains('flash') ||
              b.title.toLowerCase().contains('deal'),
        )
        .toList();
    if (flash.isNotEmpty) {
      return flash.take(3).toList();
    }
    return all.take(3).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CustomerBanner>> bannersState =
        ref.watch(customerBannersProvider);

    return bannersState.maybeWhen(
      data: (List<CustomerBanner> banners) {
        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }
        final List<CustomerBanner> flash = _flashBanners(banners);
        return HomeSectionEntrance(
          delay: const Duration(milliseconds: 250),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CountdownBanner(endsAt: flash.first.endsAt),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: flash.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    return _FlashDealCard(banner: flash[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _CountdownBanner extends StatefulWidget {
  const _CountdownBanner({this.endsAt});

  final DateTime? endsAt;

  @override
  State<_CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<_CountdownBanner> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final DateTime end = widget.endsAt ?? _nextMidnight();
    setState(() {
      _remaining = end.difference(DateTime.now());
      if (_remaining.isNegative) {
        _remaining = Duration.zero;
      }
    });
  }

  DateTime _nextMidnight() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final int h = _remaining.inHours;
    final int m = _remaining.inMinutes.remainder(60);
    final int s = _remaining.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.offerOrange, Color(0xFFFB923C)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ends in ${_pad(h)}:${_pad(m)}:${_pad(s)}',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            'Limited time',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashDealCard extends StatelessWidget {
  const _FlashDealCard({required this.banner});

  final CustomerBanner banner;

  @override
  Widget build(BuildContext context) {
    return MndPressable(
      onTap: () => openCustomerSearch(context),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              banner.startColor,
              AppColors.offerOrange.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.offerOrange.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              banner.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Text(
                  'SAVE',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'HOT',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
