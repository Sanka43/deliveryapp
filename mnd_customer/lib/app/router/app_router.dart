import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/utils/go_router_refresh_stream.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:mnd_delivery_app/features/auth/presentation/pages/login_page.dart';
import 'package:mnd_delivery_app/features/auth/presentation/pages/onboarding_page.dart';
import 'package:mnd_delivery_app/features/auth/presentation/pages/otp_verification_page.dart';
import 'package:mnd_delivery_app/features/auth/presentation/pages/splash_page.dart';
import 'package:mnd_delivery_app/features/auth/presentation/pages/wrong_dedicated_app_page.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/user_role_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/customer_home_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/customer_shell_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/customer_profile_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/edit_customer_profile_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/food_products_page.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/pages/job_applications_page.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/pages/job_detail_page.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/pages/customer_jobs_menu_page.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/pages/jobs_home_page.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/pages/my_job_applications_page.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/pages/my_job_posts_page.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/pages/post_job_page.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/pages/saved_jobs_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/language_selector_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/notification_settings_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/customer_search_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/saved_addresses_page.dart';
import 'package:mnd_delivery_app/features/cart/presentation/pages/cart_page.dart';
import 'package:mnd_delivery_app/features/checkout/presentation/pages/checkout_page.dart';
import 'package:mnd_delivery_app/features/orders/presentation/pages/live_rider_tracking_page.dart';
import 'package:mnd_delivery_app/features/orders/presentation/pages/order_details_page.dart';
import 'package:mnd_delivery_app/features/orders/presentation/pages/orders_history_page.dart';
import 'package:mnd_delivery_app/features/store/presentation/pages/store_details_page.dart';

String _normalizedRole(String? role) {
  final String r = (role ?? '').toLowerCase().trim();
  if (r.isEmpty) {
    return 'customer';
  }
  return r;
}

String _homeForNormalizedRole(String normalizedRole) {
  switch (normalizedRole) {
    case 'rider':
      return AppRoutes.wrongAppRider;
    case 'vendor':
      return AppRoutes.wrongAppVendor;
    case 'admin':
      return AppRoutes.admin;
    case 'customer':
    default:
      return AppRoutes.customer;
  }
}

/// Logged-in users only: enforce one app per role on this build (customer APK).
String? _roleAccessRedirect({
  required String normalizedRole,
  required String matchedLocation,
}) {
  if (normalizedRole == 'admin') {
    if (matchedLocation == AppRoutes.wrongAppRider ||
        matchedLocation == AppRoutes.wrongAppVendor) {
      return AppRoutes.admin;
    }
    return null;
  }

  if (normalizedRole == 'rider') {
    if (matchedLocation == AppRoutes.wrongAppRider) {
      return null;
    }
    return AppRoutes.wrongAppRider;
  }

  if (normalizedRole == 'vendor') {
    if (matchedLocation == AppRoutes.wrongAppVendor) {
      return null;
    }
    return AppRoutes.wrongAppVendor;
  }

  if (matchedLocation == AppRoutes.wrongAppRider ||
      matchedLocation == AppRoutes.wrongAppVendor ||
      matchedLocation == AppRoutes.admin) {
    return AppRoutes.customer;
  }

  return null;
}

/// Root navigator for FCM deep links and in-app snackbars.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final AsyncValue<String?> userRoleState = ref.watch(userRoleProvider);
  final bool guestBrowsing = ref.watch(guestBrowsingProvider);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
    redirect: (BuildContext context, GoRouterState state) {
      final bool isLoggedIn = auth.currentUser != null;
      final bool isSplash = state.matchedLocation == AppRoutes.splash;
      final bool isLoggingIn = state.matchedLocation == AppRoutes.login;
      final bool isOnboarding = state.matchedLocation == AppRoutes.onboarding;
      final bool isOtp = state.matchedLocation == AppRoutes.otp;
      final bool isAuthFlowRoute =
          isSplash || isLoggingIn || isOnboarding || isOtp;

      final bool isCustomerGuestRoute = guestBrowsing &&
          (state.matchedLocation == AppRoutes.customer ||
              state.matchedLocation.startsWith('${AppRoutes.customer}/'));

      if (!isLoggedIn && !isLoggingIn && !isOnboarding && !isOtp) {
        if (isCustomerGuestRoute) {
          return null;
        }
        return AppRoutes.login;
      }

      if (!isLoggedIn) {
        return null;
      }

      if (userRoleState.isLoading) {
        return isSplash ? null : AppRoutes.splash;
      }

      final String normalizedRole = _normalizedRole(userRoleState.valueOrNull);
      final String home = _homeForNormalizedRole(normalizedRole);

      if (isAuthFlowRoute) {
        return home;
      }

      return _roleAccessRedirect(
        normalizedRole: normalizedRole,
        matchedLocation: state.matchedLocation,
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (BuildContext context, GoRouterState state) {
          final String verificationId =
              state.uri.queryParameters['verificationId'] ?? '';
          final String phoneNumber = state.uri.queryParameters['phone'] ?? '';
          if (verificationId.isEmpty || phoneNumber.isEmpty) {
            return const LoginPage();
          }
          return OtpVerificationPage(
            verificationId: verificationId,
            phoneNumber: phoneNumber,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.wrongAppRider,
        builder: (BuildContext context, GoRouterState state) =>
            const WrongDedicatedAppPage(forRider: true),
      ),
      GoRoute(
        path: AppRoutes.wrongAppVendor,
        builder: (BuildContext context, GoRouterState state) =>
            const WrongDedicatedAppPage(forRider: false),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) {
          return CustomerShellPage(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.customer,
                builder: (BuildContext context, GoRouterState state) =>
                    const CustomerHomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.customerSearch,
                builder: (BuildContext context, GoRouterState state) =>
                    const CustomerSearchPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.customerOrders,
                builder: (BuildContext context, GoRouterState state) =>
                    const OrdersHistoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.customerProfile,
                builder: (BuildContext context, GoRouterState state) =>
                    const CustomerProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.customerFood,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const FoodProductsPage(),
      ),
      GoRoute(
        path: AppRoutes.customerJobs,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const JobsHomePage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'post',
            builder: (BuildContext context, GoRouterState state) =>
                const PostJobPage(),
          ),
          GoRoute(
            path: 'saved',
            builder: (BuildContext context, GoRouterState state) =>
                const SavedJobsPage(),
          ),
          GoRoute(
            path: 'my-posts',
            builder: (BuildContext context, GoRouterState state) =>
                const MyJobPostsPage(),
          ),
          GoRoute(
            path: 'my-applications',
            builder: (BuildContext context, GoRouterState state) =>
                const MyJobApplicationsPage(),
          ),
          GoRoute(
            path: ':jobId',
            builder: (BuildContext context, GoRouterState state) {
              final String jobId = state.pathParameters['jobId'] ?? '';
              return JobDetailPage(jobId: jobId);
            },
            routes: <RouteBase>[
              GoRoute(
                path: 'applications',
                builder: (BuildContext context, GoRouterState state) {
                  final String jobId = state.pathParameters['jobId'] ?? '';
                  return JobApplicationsPage(jobId: jobId);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.customerCart,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const CartPage(),
      ),
      GoRoute(
        path: AppRoutes.customerCheckout,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const CheckoutPage(),
      ),
      GoRoute(
        path: '${AppRoutes.customerOrders}/:orderId/tracking',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String orderId = state.pathParameters['orderId'] ?? '';
          if (orderId.isEmpty) {
            return const OrdersHistoryPage();
          }
          return LiveRiderTrackingPage(orderId: orderId);
        },
      ),
      GoRoute(
        path: '${AppRoutes.customerOrders}/:orderId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String orderId = state.pathParameters['orderId'] ?? '';
          if (orderId.isEmpty) {
            return const OrdersHistoryPage();
          }
          return OrderDetailsPage(orderId: orderId);
        },
      ),
      GoRoute(
        path: AppRoutes.customerSavedAddresses,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SavedAddressesPage(),
      ),
      GoRoute(
        path: AppRoutes.customerProfileJobs,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const CustomerJobsMenuPage(),
      ),
      GoRoute(
        path: AppRoutes.customerEditProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const EditCustomerProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.customerNotificationSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationSettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.customerLanguage,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const LanguageSelectorPage(),
      ),
      GoRoute(
        path: '${AppRoutes.customerStoreDetails}/:storeId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String storeId = state.pathParameters['storeId'] ?? '';
          final String storeName =
              state.uri.queryParameters['name'] ?? 'Store Details';
          final String imageUrl = state.uri.queryParameters['imageUrl'] ?? '';
          final String tag = state.uri.queryParameters['tag'] ?? 'Store';
          final String eta = state.uri.queryParameters['eta'] ?? 'N/A';
          final String deliveryFee =
              state.uri.queryParameters['deliveryFee'] ?? 'LKR 0';
          final String storeAddress = state.uri.queryParameters['address'] ?? '';
          final String storePhone = state.uri.queryParameters['phone'] ?? '';
          final double rating = double.tryParse(
                state.uri.queryParameters['rating'] ?? '',
              ) ??
              0;

          return StoreDetailsPage(
            storeId: storeId,
            storeName: storeName,
            imageUrl: imageUrl,
            tag: tag,
            rating: rating,
            eta: eta,
            deliveryFee: deliveryFee,
            storeAddress: storeAddress,
            storePhone: storePhone,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (BuildContext context, GoRouterState state) =>
            const AdminDashboardPage(),
      ),
    ],
  );
});
