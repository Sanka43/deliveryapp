import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/app/providers/rider_auth_state_provider.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_onboarding_provider.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_registration_provider.dart';

class RiderSplashPage extends ConsumerStatefulWidget {
  const RiderSplashPage({super.key});

  @override
  ConsumerState<RiderSplashPage> createState() => _RiderSplashPageState();
}

class _RiderSplashPageState extends ConsumerState<RiderSplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeNext());
  }

  Future<void> _routeNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) {
      return;
    }

    final bool onboardingDone =
        ref.read(riderOnboardingCompleteProvider).valueOrNull ?? false;
    if (!onboardingDone) {
      context.go(RoutePaths.onboarding);
      return;
    }

    final AsyncValue<dynamic> auth = ref.read(riderAuthStateProvider);
    if (auth.isLoading) {
      await auth.when(
        data: (_) async {},
        loading: () async {
          await ref.read(riderAuthStateProvider.future);
        },
        error: (_, __) async {},
      );
    }

    if (!mounted) {
      return;
    }

    final bool signedIn = ref.read(riderAuthStateProvider).valueOrNull != null;
    if (!signedIn) {
      context.go(RoutePaths.login);
      return;
    }

    final bool profileComplete =
        ref.read(riderHasCompleteProfileProvider).valueOrNull ?? false;
    context.go(profileComplete ? RoutePaths.shell : RoutePaths.register);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF1E3A8A),
              AppColors.primaryBlue,
              Color(0xFF60A5FA),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.two_wheeler_rounded, size: 72, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'MND Rider',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 28),
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            ],
          ),
        ),
      ),
    );
  }
}
