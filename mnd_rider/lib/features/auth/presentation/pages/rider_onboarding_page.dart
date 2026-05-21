import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_onboarding_provider.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/rider_auth_gradient_scaffold.dart';

class RiderOnboardingPage extends ConsumerStatefulWidget {
  const RiderOnboardingPage({super.key});

  @override
  ConsumerState<RiderOnboardingPage> createState() => _RiderOnboardingPageState();
}

class _RiderOnboardingPageState extends ConsumerState<RiderOnboardingPage> {
  final PageController _pageController = PageController();
  int _index = 0;

  static const List<_OnboardingSlide> _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      icon: Icons.delivery_dining_rounded,
      title: 'Deliver with MND',
      body: 'Accept nearby jobs, navigate pickups and dropoffs, and earn on every trip.',
    ),
    _OnboardingSlide(
      icon: Icons.payments_rounded,
      title: 'Track your earnings',
      body: 'See daily, weekly, and monthly payouts in one clean dashboard.',
    ),
    _OnboardingSlide(
      icon: Icons.verified_user_rounded,
      title: 'Stay verified',
      body: 'Upload your license and vehicle details once — then go online in seconds.',
    ),
  ];

  @override
  void dispose() {
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
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RiderAuthGradientScaffold(
      child: Column(
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _finish,
              child: const Text('Skip', style: TextStyle(color: Colors.white70)),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (int i) => setState(() => _index = i),
              itemBuilder: (BuildContext context, int i) {
                final _OnboardingSlide slide = _slides[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(slide.icon, size: 48, color: Colors.white),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        slide.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        slide.body,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 16,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(_slides.length, (int i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _index == i ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _index == i ? Colors.white : Colors.white38,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryBlue,
                ),
                child: Text(_index == _slides.length - 1 ? 'Get started' : 'Next'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
