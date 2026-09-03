import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/app/providers/rider_auth_state_provider.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/core/widgets/rider_loading_scaffold.dart';
import 'package:mnd_rider/features/auth/presentation/pages/rider_onboarding_page.dart';
import 'package:mnd_rider/features/auth/presentation/pages/rider_otp_verification_page.dart';
import 'package:mnd_rider/features/auth/presentation/pages/rider_phone_login_page.dart';
import 'package:mnd_rider/features/auth/presentation/pages/rider_register_page.dart';
import 'package:mnd_rider/features/auth/presentation/pages/rider_register_submitting_page.dart';
import 'package:mnd_rider/features/auth/presentation/pages/rider_splash_page.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_phone_auth_provider.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_registration_provider.dart';
import 'package:mnd_rider/features/earnings/presentation/pages/rider_transactions_page.dart';
import 'package:mnd_rider/features/notifications/presentation/pages/rider_notifications_page.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';
import 'package:mnd_rider/features/profile/presentation/pages/rider_edit_profile_page.dart';
import 'package:mnd_rider/features/profile/presentation/pages/rider_renew_documents_page.dart';
import 'package:mnd_rider/features/profile/presentation/pages/rider_settings_page.dart';
import 'package:mnd_rider/features/history/presentation/pages/rider_delivery_history_page.dart';
import 'package:mnd_rider/features/reports/domain/rider_report_data.dart';
import 'package:mnd_rider/features/reports/presentation/pages/rider_report_page.dart';
import 'package:mnd_rider/features/reports/presentation/pages/rider_report_preview_page.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/orders/presentation/pages/rider_order_detail_page.dart';
import 'package:mnd_rider/features/shell/presentation/pages/rider_shell_page.dart';
import 'package:mnd_rider/features/shell/presentation/widgets/rider_app_shell.dart';
import 'package:mnd_rider/features/trip/presentation/pages/rider_trip_navigation_page.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';
import 'package:mnd_rider/features/trips/presentation/pages/rider_ride_navigation_page.dart';

/// Root navigator for update prompts and in-app snackbars outside build context.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final AuthRedirectNotifier refresh = ref.watch(authRedirectNotifierProvider);
  ref.listen<AsyncValue<bool>>(riderHasCompleteProfileProvider, (_, __) {
    refresh.notify();
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final String loc = state.matchedLocation;
      final bool onAuth = RoutePaths.isPublicAuthRoute(loc);
      final bool onSplash = loc == RoutePaths.splash;
      final bool onOnboarding = loc == RoutePaths.onboarding;

      // Splash owns its own navigation.
      if (onSplash) {
        return null;
      }

      final AsyncValue<User?> auth = ref.read(riderAuthStateProvider);
      if (auth.isLoading) {
        return null;
      }

      final bool signedIn = auth.valueOrNull != null;

      // Signed-in riders should never see first-run onboarding.
      if (signedIn && onOnboarding) {
        final AsyncValue<bool> profileGate =
            ref.read(riderHasCompleteProfileProvider);
        if (profileGate.isLoading) {
          return RoutePaths.splash;
        }
        if (profileGate.hasError) {
          return RoutePaths.shell;
        }
        return (profileGate.valueOrNull ?? false)
            ? RoutePaths.shell
            : RoutePaths.register;
      }

      if (onOnboarding) {
        return null;
      }

      if (!signedIn) {
        if (loc == RoutePaths.otp) {
          final bool hasOtp =
              ref.read(riderPhoneAuthProvider).hasPendingOtpSession;
          if (!hasOtp) {
            return RoutePaths.login;
          }
          return null;
        }
        if (onAuth) {
          return null;
        }
        return RoutePaths.login;
      }

      final AsyncValue<bool> profileGate = ref.read(riderHasCompleteProfileProvider);
      // Profile stream remounts on uid change — wait so we don't bounce a
      // completed rider from /home → /auth/register during the first snapshot.
      if (profileGate.isLoading || profileGate.isRefreshing) {
        return null;
      }
      if (profileGate.hasError) {
        // Offline / permission-denied is not "incomplete registration".
        if (onAuth &&
            loc != RoutePaths.login &&
            loc != RoutePaths.otp) {
          return RoutePaths.shell;
        }
        return null;
      }
      final bool profileComplete = profileGate.asData?.value ?? false;

      // Incomplete registration → register / OTP / submitting. Login stays
      // reachable so a signed-in incomplete rider can sign out and switch numbers.
      if (!profileComplete &&
          loc != RoutePaths.register &&
          loc != RoutePaths.registerSubmitting &&
          loc != RoutePaths.otp &&
          loc != RoutePaths.login) {
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
        builder: (_, __) => const RiderOtpVerificationPage(),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (_, __) => const RiderRegisterPage(),
      ),
      GoRoute(
        path: RoutePaths.registerSubmitting,
        builder: (_, __) => const RiderRegisterSubmittingPage(),
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
        path: '${RoutePaths.ride}/:tripId',
        builder: (_, GoRouterState state) {
          final RiderPassengerTrip? trip = state.extra as RiderPassengerTrip?;
          if (trip != null) {
            return RiderRideNavigationPage(trip: trip);
          }
          final String id = state.pathParameters['tripId'] ?? '';
          return _RideLoader(tripId: id);
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
        path: RoutePaths.notifications,
        builder: (_, __) => const RiderNotificationsPage(),
      ),
      GoRoute(
        path: RoutePaths.report,
        builder: (_, __) => const RiderReportPage(),
      ),
      GoRoute(
        path: RoutePaths.reportPreview,
        builder: (_, GoRouterState state) {
          final RiderReportPreviewArgs? args =
              state.extra as RiderReportPreviewArgs?;
          if (args == null) {
            return const _RouteFallbackPage(
              message: 'Report not available. Generate a report first.',
              fallbackPath: RoutePaths.report,
              fallbackLabel: 'Go to reports',
            );
          }
          return RiderReportPreviewPage(args: args);
        },
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
            return const _RouteFallbackPage(
              message: 'Profile not available. Open your profile first.',
              fallbackPath: RoutePaths.settings,
              fallbackLabel: 'Go to settings',
            );
          }
          return RiderEditProfilePage(initialProfile: profile);
        },
      ),
      GoRoute(
        path: RoutePaths.renewDocuments,
        builder: (_, __) => const RiderRenewDocumentsPage(),
      ),
    ],
    errorBuilder: (_, GoRouterState state) => const Scaffold(
      body: Center(child: Text('This page could not be found.')),
    ),
  );
});

/// Shown when a route that requires `extra` data (e.g. a deep link or a
/// restored navigation stack) is reached without it. Sends the rider
/// somewhere useful instead of a dead-end message.
class _RouteFallbackPage extends StatelessWidget {
  const _RouteFallbackPage({
    required this.message,
    required this.fallbackPath,
    required this.fallbackLabel,
  });

  final String message;
  final String fallbackPath;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(fallbackPath),
                child: Text(fallbackLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      error: (Object e, _) => Scaffold(
        body: Center(child: Text(userFacingError(e))),
      ),
    );
  }
}

class _RideLoader extends ConsumerWidget {
  const _RideLoader({required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RiderPassengerTrip?> trip =
        ref.watch(riderPassengerTripProvider(tripId));
    return trip.when(
      data: (RiderPassengerTrip? t) {
        if (t == null) {
          return const Scaffold(
            body: Center(child: Text('Ride not found')),
          );
        }
        return RiderRideNavigationPage(trip: t);
      },
      loading: () => const RiderLoadingScaffold(message: 'Loading ride…'),
      error: (Object e, _) => Scaffold(
        body: Center(child: Text(userFacingError(e))),
      ),
    );
  }
}
