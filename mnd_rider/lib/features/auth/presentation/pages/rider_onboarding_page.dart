import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_onboarding_provider.dart';

class RiderOnboardingPage extends ConsumerStatefulWidget {
  const RiderOnboardingPage({super.key});

  @override
  ConsumerState<RiderOnboardingPage> createState() => _RiderOnboardingPageState();
}

class _RiderOnboardingPageState extends ConsumerState<RiderOnboardingPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _copyController;
  late final Animation<double> _copyFade;
  late final Animation<Offset> _copySlide;
  int _index = 0;

  static const List<_OnboardingSlide> _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      imageAsset: 'assets/images/onboarding/deliver.jpg',
      title: 'Deliver with MND',
      body:
          'Accept nearby jobs, navigate pickups and dropoffs, and earn on every trip.',
    ),
    _OnboardingSlide(
      imageAsset: 'assets/images/onboarding/earnings.jpg',
      title: 'Track your earnings',
      body: 'See daily, weekly, and monthly payouts in one clean dashboard.',
    ),
    _OnboardingSlide(
      imageAsset: 'assets/images/onboarding/verified.jpg',
      title: 'Stay verified',
      body:
          'Upload your license and vehicle details once — then go online in seconds.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _copyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _copyFade = CurvedAnimation(parent: _copyController, curve: Curves.easeOut);
    _copySlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _copyController, curve: Curves.easeOutCubic),
    );
    _copyController.forward();
  }

  @override
  void dispose() {
    _copyController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(riderOnboardingCompleteProvider.notifier).markComplete();
    if (mounted) {
      context.go(RoutePaths.login);
    }
  }

  void _next() {
    if (_index >= _slides.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _copyController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _index == _slides.length - 1;
    final _OnboardingSlide slide = _slides[_index];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.darkCanvas,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (BuildContext context, int i) {
                return Image.asset(
                  _slides[i].imageAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) {
                    return const ColoredBox(color: AppColors.heroNavyDeep);
                  },
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
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.78),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
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
                              'MND RIDER',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 2.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              slide.title,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 32,
                                height: 1.15,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              slide.body,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(_slides.length, (int i) {
                        final bool active = _index == i;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primaryBlue
                                : Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: AppSpacing.ctaHeight,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.buttonRadius,
                            ),
                          ),
                        ),
                        child: Text(
                          isLast ? 'Get started' : 'Next',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
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

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.imageAsset,
    required this.title,
    required this.body,
  });

  final String imageAsset;
  final String title;
  final String body;
}
