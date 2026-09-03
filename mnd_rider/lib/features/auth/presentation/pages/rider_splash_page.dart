import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:mnd_rider/app/providers/rider_auth_state_provider.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/features/auth/domain/rider_profile_document.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_onboarding_provider.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_registration_provider.dart';

class RiderSplashPage extends ConsumerStatefulWidget {
  const RiderSplashPage({super.key});

  @override
  ConsumerState<RiderSplashPage> createState() => _RiderSplashPageState();
}

class _RiderSplashPageState extends ConsumerState<RiderSplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _pulse;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _copyFade;
  late final Animation<Offset> _copySlide;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _logoFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _copyFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.25, 0.7, curve: Curves.easeOut),
    );
    _copySlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _footerFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.55, 1, curve: Curves.easeOut),
    );

    _enter.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeNext());
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _routeNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) {
      return;
    }

    final AsyncValue<dynamic> auth = ref.read(riderAuthStateProvider);
    if (auth.isLoading) {
      try {
        await ref.read(riderAuthStateProvider.future);
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }

    final bool signedIn = ref.read(riderAuthStateProvider).valueOrNull != null;

    // Already signed in → never show first-run onboarding.
    if (signedIn) {
      final bool onboardingDone =
          ref.read(riderOnboardingCompleteProvider).valueOrNull ?? false;
      if (!onboardingDone) {
        await ref.read(riderOnboardingCompleteProvider.notifier).markComplete();
      }
      if (!mounted) {
        return;
      }
      try {
        RiderProfileDocument? profile;
        Object? profileError;
        for (int attempt = 0; attempt < 3; attempt++) {
          try {
            if (attempt > 0) {
              ref.invalidate(riderAuthProfileProvider);
              await Future<void>.delayed(
                Duration(milliseconds: 350 * attempt),
              );
            }
            profile = await ref.read(riderAuthProfileProvider.future);
            profileError = null;
            break;
          } catch (e) {
            profileError = e;
          }
        }
        if (!mounted) {
          return;
        }
        if (profileError != null) {
          // Signed-in: never treat a fetch failure as "not registered".
          context.go(RoutePaths.shell);
          return;
        }
        context.go(
          profile?.isRegistrationComplete == true
              ? RoutePaths.shell
              : RoutePaths.register,
        );
      } catch (_) {
        if (!mounted) {
          return;
        }
        context.go(RoutePaths.shell);
      }
      return;
    }

    final bool onboardingDone =
        ref.read(riderOnboardingCompleteProvider).valueOrNull ?? false;
    if (!onboardingDone) {
      // Prefs may still be loading on cold start.
      final bool resolved =
          await ref.read(riderOnboardingCompleteProvider.future);
      if (!mounted) {
        return;
      }
      if (!resolved) {
        context.go(RoutePaths.onboarding);
        return;
      }
    }

    context.go(RoutePaths.login);
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.heroNavyDeep,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const _SplashBackdrop(),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(28, 24, 28, 20 + bottom * 0.25),
                child: Column(
                  children: <Widget>[
                    const Spacer(flex: 2),
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: const _SplashBrandMark(),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: _copyFade,
                      child: SlideTransition(
                        position: _copySlide,
                        child: Column(
                          children: <Widget>[
                            Text(
                              'MND Rider',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Deliver nearby. Earn every trip.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _footerFade,
                      child: SizedBox(
                        height: 148,
                        width: 220,
                        child: Lottie.asset(
                          'assets/animations/delivery_bike.json',
                          fit: BoxFit.contain,
                          errorBuilder: (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return Icon(
                              Icons.two_wheeler_rounded,
                              size: 56,
                              color: Colors.white.withValues(alpha: 0.85),
                            );
                          },
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: _footerFade,
                      child: _SplashProgress(pulse: _pulse),
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

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.heroNavyDeep,
            AppColors.heroNavy,
            AppColors.primaryBlue,
          ],
          stops: <double>[0, 0.48, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandSecondary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.28,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue.withValues(alpha: 0.22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBrandMark extends StatelessWidget {
  const _SplashBrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/branding/app_icon.png',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return const ColoredBox(
            color: AppColors.primaryBlue,
            child: Icon(
              Icons.two_wheeler_rounded,
              size: 52,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}

class _SplashProgress extends StatelessWidget {
  const _SplashProgress({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AnimatedBuilder(
          animation: pulse,
          builder: (BuildContext context, Widget? child) {
            return Container(
              width: 120,
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: Colors.white.withValues(alpha: 0.18),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.35 + (pulse.value * 0.45),
                child: child,
              ),
            );
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.55),
                  Colors.white,
                  AppColors.brandSecondary.withValues(alpha: 0.95),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Getting ready…',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
