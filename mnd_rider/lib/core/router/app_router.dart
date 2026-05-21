import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/app/providers/rider_auth_state_provider.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/widgets/rider_loading_scaffold.dart';
import 'package:mnd_rider/features/auth/presentation/pages/rider_onboarding_page.dart';
import 'package:mnd_rider/features/auth/presentation/pages/rider_otp_verification_page.dart';
import 'package:mnd_rider/features/auth/presentation/pages/rider_phone_login_page.dart';
import 'package:mnd_rider/features/auth/presentation/pages/rider_register_page.dart';
import 'package:mnd_rider/features/auth/presentation/pages/rider_splash_page.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_registration_provider.dart';
import 'package:mnd_rider/features/earnings/presentation/pages/rider_transactions_page.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';
import 'package:mnd_rider/features/profile/presentation/pages/rider_edit_profile_page.dart';
import 'package:mnd_rider/features/profile/presentation/pages/rider_settings_page.dart';
import 'package:mnd_rider/features/history/presentation/pages/rider_delivery_history_page.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/orders/presentation/pages/rider_order_detail_page.dart';
import 'package:mnd_rider/features/shell/presentation/pages/rider_shell_page.dart';
import 'package:mnd_rider/features/shell/presentation/widgets/rider_app_shell.dart';
import 'package:mnd_rider/features/trip/presentation/pages/rider_trip_navigation_page.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final AuthRedirectNotifier refresh = ref.watch(authRedirectNotifierProvider);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final String loc = state.matchedLocation;
      final bool onAuth = RoutePaths.isPublicAuthRoute(loc);
      final bool onSplashOrOnboarding =
          loc == RoutePaths.splash || loc == RoutePaths.onboarding;

      if (onSplashOrOnboarding) {
        return null;
      }

      final AsyncValue<User?> auth = ref.read(riderAuthStateProvider);
      if (auth.isLoading) {
        return null;
      }

      final bool signedIn = auth.valueOrNull != null;

      if (!signedIn) {
        if (onAuth) {
          return null;
        }
        return RoutePaths.login;
      }

      final AsyncValue<bool> profileGate = ref.read(riderHasCompleteProfileProvider);
      if (profileGate.isLoading) {
        return null;
      }
      final bool profileComplete = profileGate.valueOrNull ?? false;

      if (!profileComplete && loc != RoutePaths.register) {
        return RoutePaths.register;
      }

      if (profileComplete && onAuth) {
        return RoutePaths.shell;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.splash,
        builder: (_, __) => const RiderSplashPage(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (_, __) => const RiderOnboardingPage(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (_, __) => const RiderPhoneLoginPage(),
      ),
      GoRoute(
        path: RoutePaths.otp,
        builder: (_, GoRouterState state) {
          final String verificationId =
              state.uri.queryParameters['verificationId'] ?? '';
          final String phone = state.uri.queryParameters['phone'] ?? '';
          if (verificationId.isEmpty || phone.isEmpty) {
            return const RiderPhoneLoginPage();
          }
          return RiderOtpVerificationPage(
            verificationId: verificationId,
            phoneNumber: phone,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (_, __) => const RiderRegisterPage(),
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return RiderAppShell(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.shell,
            builder: (_, __) => const RiderShellPage(),
          ),
        ],
      ),
      GoRoute(
        path: '${RoutePaths.orderDetail}/:orderId',
        builder: (_, GoRouterState state) {
          final String id = state.pathParameters['orderId'] ?? '';
          return RiderOrderDetailPage(orderId: id);
        },
      ),
      GoRoute(
        path: '${RoutePaths.trip}/:orderId',
        builder: (_, GoRouterState state) {
          final RiderOrderDetail? order = state.extra as RiderOrderDetail?;
          if (order != null) {
            return RiderTripNavigationPage(order: order);
          }
          final String id = state.pathParameters['orderId'] ?? '';
          return _TripLoader(orderId: id);
        },
      ),
      GoRoute(
        path: RoutePaths.history,
        builder: (_, __) => const RiderDeliveryHistoryPage(),
      ),
      GoRoute(
        path: RoutePaths.transactions,
        builder: (_, __) => const RiderTransactionsPage(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (_, __) => const RiderSettingsPage(),
      ),
      GoRoute(
        path: RoutePaths.profileEdit,
        builder: (_, GoRouterState state) {
          final RiderProfile? profile = state.extra as RiderProfile?;
          if (profile == null || profile.uid.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Profile not available')),
            );
          }
          return RiderEditProfilePage(initialProfile: profile);
        },
      ),
    ],
    errorBuilder: (_, GoRouterState state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});

class _TripLoader extends ConsumerWidget {
  const _TripLoader({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RiderOrderDetail?> order =
        ref.watch(riderOrderDetailProvider(orderId));
    return order.when(
      data: (RiderOrderDetail? d) {
        if (d == null) {
          return const Scaffold(
            body: Center(child: Text('Order not found')),
          );
        }
        return RiderTripNavigationPage(order: d);
      },
      loading: () => const RiderLoadingScaffold(message: 'Loading trip…'),
      error: (Object e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }
}
