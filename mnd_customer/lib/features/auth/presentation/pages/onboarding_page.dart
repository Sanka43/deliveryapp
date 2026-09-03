import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-run onboarding — full-bleed photo slides, then login.
///
/// Matches the rider app's onboarding pattern: full-screen photo per slide,
/// a bottom gradient scrim for legibility, and copy anchored at the bottom.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _copyController;
  late final Animation<double> _copyFade;
  late final Animation<Offset> _copySlide;

  double _pageValue = 0;
  int _currentPage = 0;

  final List<_OnboardingItem> _items = const <_OnboardingItem>[
    _OnboardingItem(
      image: 'assets/images/onboarding/order.jpg',
      title: 'Everything You Need, In One Place',
      subtitle:
          'Food, groceries, rides and more. Get the services you need, all from one convenient app.',
    ),
    _OnboardingItem(
      image: 'assets/images/onboarding/track.jpg',
      title: 'Fast, Easy & Reliable',
      subtitle:
          'Order what you need or book a ride in just a few taps. We make everyday tasks simple and convenient.',
    ),
    _OnboardingItem(
      image: 'assets/images/onboarding/more.jpg',
      title: 'One App. Everyday Convenience.',
      subtitle:
          'From your daily meals and groceries to getting around, MND Delivery is here to make life easier.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _pageValue = _pageController.page ?? _currentPage.toDouble();
      });
    });
    _copyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _copyFade = CurvedAnimation(parent: _copyController, curve: Curves.easeOut);
    _copySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _copyController, curve: Curves.easeOutCubic));
    _copyController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _copyController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) {
      return;
    }
    context.go(AppRoutes.login);
  }

  void _onNext() {
    HapticFeedback.selectionClick();
    if (_currentPage == _items.length - 1) {
      _completeOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToPage(int index) {
    if (index == _currentPage) {
      return;
    }
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int value) {
    setState(() => _currentPage = value);
    _copyController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _currentPage == _items.length - 1;
    final _OnboardingItem item = _items[_currentPage];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            PageView.builder(
              controller: _pageController,
              itemCount: _items.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (BuildContext context, int index) {
                final double delta = (_pageValue - index).clamp(-1.0, 1.0);
                return Transform.scale(
                  scale: 1 + (delta.abs() * 0.08),
                  child: Image.asset(
                    _items[index].image,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stack,
                    ) {
                      return const ColoredBox(color: AppColors.heroNavyDeep);
                    },
                  ),
                );
              },
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x55000000),
                    Color(0x14000000),
                    Color(0x99000000),
                    Color(0xF2000000),
                  ],
                  stops: <double>[0.0, 0.38, 0.64, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      height: 44,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isLast
                            ? const SizedBox.shrink()
                            : Align(
                                key: const ValueKey<String>('skip'),
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _completeOnboarding,
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        Colors.white.withValues(alpha: 0.78),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: Text(
                                    'Skip',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white
                                              .withValues(alpha: 0.78),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const Spacer(),
                    FadeTransition(
                      opacity: _copyFade,
                      child: SlideTransition(
                        position: _copySlide,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'MND',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppColors.brandPrimaryLight,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2.4,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              item.subtitle,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(
                        _items.length,
                        (int index) {
                          final bool active = _currentPage == index;
                          return GestureDetector(
                            onTap: () => _goToPage(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: AppSpacing.sm,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                width: active ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.brandPrimaryLight
                                      : Colors.white.withValues(alpha: 0.28),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _OnboardingCta(
                      label: isLast ? 'Get started' : 'Next',
                      onPressed: _onNext,
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

class _OnboardingCta extends StatefulWidget {
  const _OnboardingCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_OnboardingCta> createState() => _OnboardingCtaState();
}

class _OnboardingCtaState extends State<_OnboardingCta> {
  bool _pressed = false;

  void _setPressed(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.brandPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  widget.label,
                  key: ValueKey<String>(widget.label),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.image,
    required this.title,
    required this.subtitle,
  });

  final String image;
  final String title;
  final String subtitle;
}
