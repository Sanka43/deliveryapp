import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/offers/domain/customer_offer.dart';
import 'package:mnd_delivery_app/features/offers/presentation/offer_order_helpers.dart';
import 'package:mnd_delivery_app/features/offers/presentation/providers/customer_offers_provider.dart';
import 'package:shimmer/shimmer.dart';

const double _kHeroBannerHeight = 224;
const double _kHeroSlideGap = 16;
/// Virtual copies of the real slide set so last→first keeps scrolling left.
/// Web uses a smaller buffer — large virtual lists hurt CanvasKit scroll cost.
const int _kLoopCopies = kIsWeb ? 20 : 200;

/// Home hero slot: Live dispatch as default slide; live offers swipe left after it.
class HomeDispatchHero extends ConsumerStatefulWidget {
  const HomeDispatchHero({super.key});

  @override
  ConsumerState<HomeDispatchHero> createState() => _HomeDispatchHeroState();
}

class _HomeDispatchHeroState extends ConsumerState<HomeDispatchHero> {
  final ScrollController _scrollController = ScrollController();
  Timer? _autoPlayTimer;
  int _current = 0;
  int _slideCount = 0;
  int _virtualPage = 0;
  double _bannerWidth = 0;
  bool _jumping = false;

  int get _virtualCount => _slideCount * _kLoopCopies;

  int get _middleBase => (_kLoopCopies ~/ 2) * _slideCount;

  double get _extent => _bannerWidth + _kHeroSlideGap;

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
    if (_slideCount <= 1) {
      return;
    }
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_scrollController.hasClients || _bannerWidth <= 0) {
        return;
      }
      // Always advance one page leftward — never rewind to 0.
      final double target = (_virtualPage + 1) * _extent;
      _scrollController.animateTo(
        target.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _jumpToMiddleEquivalent() {
    if (_jumping ||
        !_scrollController.hasClients ||
        _slideCount <= 1 ||
        _bannerWidth <= 0) {
      return;
    }
    final int real = _virtualPage % _slideCount;
    final int minSafe = _slideCount * 2;
    final int maxSafe = _virtualCount - _slideCount * 2;
    if (_virtualPage >= minSafe && _virtualPage <= maxSafe) {
      return;
    }
    final int targetPage = _middleBase + real;
    _jumping = true;
    _scrollController.jumpTo(targetPage * _extent);
    _virtualPage = targetPage;
    _jumping = false;
  }

  void _onScroll({required bool isEnd}) {
    if (_jumping ||
        !_scrollController.hasClients ||
        _bannerWidth <= 0 ||
        _slideCount <= 0) {
      return;
    }
    final int page = (_scrollController.offset / _extent)
        .round()
        .clamp(0, _virtualCount - 1);
    _virtualPage = page;
    final int real = page % _slideCount;
    if (real != _current) {
      setState(() => _current = real);
    }
    if (isEnd) {
      _jumpToMiddleEquivalent();
    }
  }

  void _ensureLoopStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || _bannerWidth <= 0) {
        return;
      }
      if (_slideCount <= 1) {
        _scrollController.jumpTo(0);
        _virtualPage = 0;
        _current = 0;
        _syncAutoPlay();
        return;
      }
      _virtualPage = _middleBase;
      _current = 0;
      _scrollController.jumpTo(_middleBase * _extent);
      _syncAutoPlay();
      if (mounted) {
        setState(() {});
      }
    });
  }

  Widget _slideAt(int realIndex, List<CustomerOffer> offers) {
    if (realIndex == 0) {
      return const _DispatchHeroCard();
    }
    return _OfferHeroBanner(offer: offers[realIndex - 1]);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CustomerOffer>> offersState =
        ref.watch(customerLiveOffersProvider);

    return offersState.when(
      loading: () => const _HeroSkeleton(),
      error: (_, __) => const _StaticDispatchHero(),
      data: (List<CustomerOffer> offers) {
        if (offers.isEmpty) {
          return const _StaticDispatchHero();
        }

        final int slideCount = offers.length + 1;
        if (slideCount != _slideCount) {
          _slideCount = slideCount;
          _ensureLoopStart();
        }

        return HomeSectionEntrance(
          child: Column(
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double bannerWidth = constraints.maxWidth;
                  final bool widthChanged = (_bannerWidth - bannerWidth).abs() > 0.5;
                  _bannerWidth = bannerWidth;
                  if (widthChanged && _slideCount > 1) {
                    _ensureLoopStart();
                  }
                  return SizedBox(
                    height: _kHeroBannerHeight,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification n) {
                        if (n is ScrollUpdateNotification) {
                          _onScroll(isEnd: false);
                        } else if (n is ScrollEndNotification) {
                          _onScroll(isEnd: true);
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: _BannerSnapPhysics(itemExtent: _extent),
                        itemCount: _virtualCount,
                        itemBuilder: (BuildContext context, int index) {
                          final int realIndex = index % slideCount;
                          return SizedBox(
                            width: bannerWidth + _kHeroSlideGap,
                            height: _kHeroBannerHeight,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: bannerWidth,
                                height: _kHeroBannerHeight,
                                child: _slideAt(realIndex, offers),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              if (slideCount > 1) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(slideCount, (int i) {
                    final bool active = i == _current;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? AppColors.brandPrimary
                            : AppColors.textSecondary.withValues(alpha: 0.22),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Snaps horizontal banner scroll to each full-width card (+ gap).
class _BannerSnapPhysics extends ScrollPhysics {
  const _BannerSnapPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  @override
  _BannerSnapPhysics applyTo(ScrollPhysics? ancestor) {
    return _BannerSnapPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  double _targetPixels(ScrollMetrics position, double velocity) {
    final double page = position.pixels / itemExtent;
    final double targetPage;
    if (velocity < -200) {
      targetPage = page.floorToDouble();
    } else if (velocity > 200) {
      targetPage = page.ceilToDouble();
    } else {
      targetPage = page.roundToDouble();
    }
    final double maxPage =
        position.maxScrollExtent <= 0 ? 0 : position.maxScrollExtent / itemExtent;
    return targetPage.clamp(0, maxPage) * itemExtent;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final double target = _targetPixels(position, velocity);
    if ((target - position.pixels).abs() < tolerance.distance) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}

class _OfferHeroBanner extends ConsumerWidget {
  const _OfferHeroBanner({required this.offer});

  final CustomerOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.heroNavyDeep,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.heroNavy.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Product image.
          if (offer.imageUrl.isNotEmpty)
            MndNetworkImage(
              imageUrl: offer.imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              showWatermarkOnError: false,
            )
          else
            const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroNavyGradient)),
          // Even scrim so copy stays readable without a side wash.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: <Color>[
                  Color(0xCC071E5C),
                  Color(0x66071E5C),
                  Color(0x33071E5C),
                ],
                stops: <double>[0.0, 0.45, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _BannerChip(
                      icon: Icons.local_offer_rounded,
                      label: 'Offer',
                      foreground: Colors.white,
                      background: AppColors.offerOrange.withValues(alpha: 0.92),
                    ),
                    const SizedBox(width: 8),
                    _OfferCountdownChip(endsAt: offer.endsAt),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  offer.storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offer.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                if (offer.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    offer.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'From',
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            formatOfferPrice(offer.priceLkr),
                            style: textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MndPressable(
                      onTap: () => orderCustomerOffer(context, ref, offer),
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.brandPrimary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Order Now',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCountdownChip extends StatefulWidget {
  const _OfferCountdownChip({required this.endsAt});

  final DateTime endsAt;

  @override
  State<_OfferCountdownChip> createState() => _OfferCountdownChipState();
}

class _OfferCountdownChipState extends State<_OfferCountdownChip> {
  late final Timer _timer;
  late String _label;
  late bool _ended;

  @override
  void initState() {
    super.initState();
    _sync();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(_sync);
    });
  }

  @override
  void didUpdateWidget(covariant _OfferCountdownChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _sync();
    }
  }

  void _sync() {
    final DateTime now = DateTime.now();
    _ended = !widget.endsAt.isAfter(now);
    _label = _ended ? 'Ended' : formatOfferCountdown(widget.endsAt, now: now);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _ended
            ? Colors.white.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.timer_outlined,
            size: 13,
            color: _ended ? AppColors.textSecondary : const Color(0xFF1E293B),
          ),
          const SizedBox(width: 5),
          Text(
            _ended ? 'Ended' : _label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _ended
                      ? AppColors.textSecondary
                      : const Color(0xFF1E293B),
                  fontWeight: FontWeight.w800,
                  height: 1,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _StaticDispatchHero extends StatelessWidget {
  const _StaticDispatchHero();

  @override
  Widget build(BuildContext context) {
    return const HomeSectionEntrance(
      child: _DispatchHeroCard(),
    );
  }
}

class _DispatchHeroCard extends StatelessWidget {
  const _DispatchHeroCard();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      height: _kHeroBannerHeight,
      decoration: BoxDecoration(
        gradient: AppColors.heroNavyGradient,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.heroNavy.withValues(alpha: 0.26),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -40,
            top: -32,
            child: IgnorePointer(
              child: Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: -56,
            child: IgnorePointer(
              child: Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandPrimary.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Live dispatch',
                            style: text.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.route_rounded,
                        size: 17,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Anything you need,\nstraight to your door.',
                  style: text.headlineSmall?.copyWith(
                    color: Colors.white,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Food, groceries, rides and jobs in one premium flow.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.76),
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _HeroCta(
                        label: 'Order food',
                        icon: Icons.restaurant_rounded,
                        filled: true,
                        onTap: () => context.push(AppRoutes.customerFood),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroCta(
                        label: 'Find jobs',
                        icon: Icons.work_outline_rounded,
                        filled: false,
                        onTap: () => context.push(AppRoutes.customerJobs),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MndPressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: filled
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 1.3,
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -0.1,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.homeMutedFill,
      highlightColor: Colors.white,
      child: Container(
        height: _kHeroBannerHeight,
        decoration: BoxDecoration(
          color: AppColors.homeMutedFill,
          borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        ),
      ),
    );
  }
}
