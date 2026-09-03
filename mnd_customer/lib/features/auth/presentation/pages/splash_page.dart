import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/checkout/data/pending_checkout_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  /// Match HTML `#mnd-splash` so the handoff from web boot never flashes dark.
  static const Color _ink = Color(0xFF101828);
  static const Color _bgTop = Color(0xFFE5F0FF);
  static const Color _bgMid = Color(0xFFF8FBFF);

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  Future<void> _startFlow() async {
    // Yield one frame so first-frame can fire while content is already painted.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }

    final bool isLoggedIn = ref.read(firebaseAuthProvider).currentUser != null;
    if (isLoggedIn) {
      // Honor pending resume (checkout / rides) before defaulting to home.
      final String? pending = ref.read(postAuthRedirectProvider);
      if (pending != null && pending.isNotEmpty) {
        ref.read(postAuthRedirectProvider.notifier).state = null;
        context.go(pending);
        return;
      }
      // A same-tab web redirect to PayHere's hosted checkout wipes all
      // in-memory state on the way back — if the customer left a checkout
      // in progress, land them back on it (it restores itself) instead of
      // defaulting to home.
      final PendingCheckoutSnapshot? pendingCheckout =
          await PendingCheckoutStore.peek();
      if (!mounted) {
        return;
      }
      if (pendingCheckout != null) {
        context.go(AppRoutes.customerCheckout);
        return;
      }
      // Optimistic home while role loads — router redirect handles wrong roles.
      context.go(AppRoutes.customer);
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isOnboardingCompleted =
        prefs.getBool('onboarding_completed') ?? false;
    if (!mounted) {
      return;
    }
    // Signed-out cold start always lands on onboarding or login.
    // Guest browse is opt-in from the login screen (not auto-restored here),
    // so the login page is reachable every launch when not signed in.
    if (ref.read(guestBrowsingProvider)) {
      ref.read(guestBrowsingProvider.notifier).state = false;
    }
    context.go(
      isOnboardingCompleted ? AppRoutes.login : AppRoutes.onboarding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[_bgTop, _bgMid, Colors.white],
              stops: <double>[0, 0.48, 1],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 108,
                    height: 108,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'MND Delivery',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                ),
                const SizedBox(height: 14),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1463FF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
