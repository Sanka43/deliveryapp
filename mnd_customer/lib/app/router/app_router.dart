import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/config/env_config.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/utils/go_router_refresh_stream.dart';
import 'package:mnd_delivery_app/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:mnd_delivery_app/features/auth/presentation/pages/login_page.dart';
import 'package:mnd_delivery_app/features/auth/presentation/pages/onboarding_page.dart';
import 'package:mnd_delivery_app/features/auth/presentation/pages/splash_page.dart';
import 'package:mnd_delivery_app/features/auth/presentation/pages/wrong_dedicated_app_page.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/auth/presentation/widgets/auth_slide_page.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/user_role_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/customer_home_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/customer_shell_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/customer_profile_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/customer_settings_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/edit_customer_profile_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/food_products_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/grocery_products_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/legal_document_page.dart';
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
import 'package:mnd_delivery_app/features/customer/presentation/pages/customer_notifications_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/customer_search_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/customer_favorites_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/customer_shops_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/pages/saved_addresses_page.dart';
import 'package:mnd_delivery_app/features/cart/presentation/pages/cart_page.dart';
import 'package:mnd_delivery_app/features/checkout/presentation/pages/checkout_page.dart';
import 'package:mnd_delivery_app/features/checkout/presentation/pages/order_confirmation_page.dart';
import 'package:mnd_delivery_app/features/orders/presentation/pages/live_rider_tracking_page.dart';
import 'package:mnd_delivery_app/features/orders/presentation/pages/order_details_page.dart';
import 'package:mnd_delivery_app/features/orders/presentation/pages/orders_history_page.dart';
import 'package:mnd_delivery_app/features/rides/presentation/pages/rides_booking_page.dart';
import 'package:mnd_delivery_app/features/rides/presentation/pages/rides_confirm_page.dart';
import 'package:mnd_delivery_app/features/rides/presentation/pages/rides_history_page.dart';
import 'package:mnd_delivery_app/features/rides/presentation/pages/rides_live_tracking_page.dart';
import 'package:mnd_delivery_app/features/rides/presentation/pages/rides_searching_page.dart';
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
      return EnvConfig.includeAdminUi
          ? AppRoutes.admin
          : AppRoutes.wrongAppAdmin;
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
    if (EnvConfig.includeAdminUi) {
      if (matchedLocation == AppRoutes.wrongAppRider ||
          matchedLocation == AppRoutes.wrongAppVendor ||
          matchedLocation == AppRoutes.wrongAppAdmin) {
        return AppRoutes.admin;
      }
      return null;
    }
    if (matchedLocation == AppRoutes.wrongAppAdmin) {
      return null;
    }
    return AppRoutes.wrongAppAdmin;
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
      matchedLocation == AppRoutes.wrongAppAdmin ||
      matchedLocation == AppRoutes.admin) {
    return AppRoutes.customer;
  }

  return null;
}

/// Root navigator for FCM deep links and in-app snackbars.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final auth = ref.watch(firebaseAuthProvider);
  // Keep a single GoRouter instance: refresh via listenable instead of
  // watching guest/role (those watches recreated the router and reset nav).
  final GoRouterRefreshStream refresh =
      GoRouterRefreshStream(auth.authStateChanges());
  ref.onDispose(refresh.dispose);
  ref.listen<bool>(guestBrowsingProvider, (_, __) => refresh.refresh());
  ref.listen(userRoleProvider, (_, __) => refresh.refresh());
  ref.listen(authStateUserProvider, (_, __) => refresh.refresh());

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final bool isLoggedIn = auth.currentUser != null;
      final bool guestBrowsing = ref.read(guestBrowsingProvider);
      final AsyncValue<String?> userRoleState = ref.read(userRoleProvider);
      final bool isSplash = state.matchedLocation == AppRoutes.splash;
      final bool isLoggingIn = state.matchedLocation == AppRoutes.login;
      final bool isOnboarding = state.matchedLocation == AppRoutes.onboarding;
      final bool isAuthFlowRoute =
          isSplash || isLoggingIn || isOnboarding;

      final bool isCustomerGuestRoute = guestBrowsing &&
          (state.matchedLocation == AppRoutes.customer ||
              state.matchedLocation.startsWith('${AppRoutes.customer}/'));

      // Let SplashPage decide onboarding vs login vs restored guest home.
      // Without this, `/` was force-redirected to `/login` before splash ran,
      // and logged-out guests could not reliably reach auth again.
      if (!isLoggedIn) {
        if (isSplash || isLoggingIn || isOnboarding) {
          return null;
        }
        if (isCustomerGuestRoute) {
          return null;
        }
        return AppRoutes.login;
      }

      // Don't trap users on the splash / auth shell while role resolves over
      // Firestore (customers → vendors → riders). That felt like a stuck
      // "Loading" screen on web before home finally appeared.
      // Prefer last-known role from a previous session; default to customer on
      // this build (riders/vendors are redirected once role arrives).
      if (userRoleState.isLoading) {
        if (isAuthFlowRoute) {
          final String? cached = ref.read(cachedUserRoleProvider);
          return _homeForNormalizedRole(_normalizedRole(cached ?? 'customer'));
        }
        return null;
      }

      final String normalizedRole = _normalizedRole(userRoleState.valueOrNull);
      final String home = _homeForNormalizedRole(normalizedRole);

      if (isAuthFlowRoute) {
        final String? pending = ref.read(postAuthRedirectProvider);
        if (pending != null && pending.isNotEmpty) {
          ref.read(postAuthRedirectProvider.notifier).state = null;
          return pending;
        }
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
        pageBuilder: (BuildContext context, GoRouterState state) =>
            authSlidePage(
          key: state.pageKey,
          name: state.matchedLocation,
          child: const LoginPage(),
        ),
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
      GoRoute(
        path: AppRoutes.wrongAppAdmin,
        builder: (BuildContext context, GoRouterState state) =>
            const WrongDedicatedAppPage(forRider: false, forAdmin: true),
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
                path: AppRoutes.customerOrders,
                builder: (BuildContext context, GoRouterState state) =>
                    const OrdersHistoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.customerFavorites,
                builder: (BuildContext context, GoRouterState state) =>
                    const CustomerFavoritesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.customerSettings,
                builder: (BuildContext context, GoRouterState state) =>
                    const CustomerSettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.customerSearch,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String? q = state.uri.queryParameters['q'];
          return CustomerSearchPage(initialQuery: q);
        },
      ),
      GoRoute(
        path: AppRoutes.customerShops,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const CustomerShopsPage(),
      ),
      GoRoute(
        path: AppRoutes.customerFood,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const FoodProductsPage(),
      ),
      GoRoute(
        path: AppRoutes.customerGrocery,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const GroceryProductsPage(),
      ),
      GoRoute(
        path: AppRoutes.customerRides,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const RidesBookingPage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'vehicle',
            builder: (BuildContext context, GoRouterState state) =>
                const RidesConfirmPage(),
          ),
          GoRoute(
            // Legacy deep link — confirm page owns the review step.
            path: 'review',
            redirect: (BuildContext context, GoRouterState state) =>
                AppRoutes.customerRidesVehicle,
          ),
          GoRoute(
            path: 'history',
            builder: (BuildContext context, GoRouterState state) =>
                const RidesHistoryPage(),
          ),
          GoRoute(
            path: 'trips/:tripId',
            builder: (BuildContext context, GoRouterState state) {
              final String tripId = state.pathParameters['tripId'] ?? '';
              return RidesSearchingPage(tripId: tripId);
            },
            routes: <RouteBase>[
              GoRoute(
                path: 'tracking',
                builder: (BuildContext context, GoRouterState state) {
                  final String tripId = state.pathParameters['tripId'] ?? '';
                  return RidesLiveTrackingPage(tripId: tripId);
                },
              ),
            ],
          ),
        ],
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
        path: AppRoutes.customerOrderConfirmation,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final Object? extra = state.extra;
          final Map<String, dynamic> args =
              extra is Map<String, dynamic> ? extra : const <String, dynamic>{};
          return OrderConfirmationPage(
            orderId: (args['orderId'] as String?) ?? '',
            trackingNumber: args['trackingNumber'] as String?,
            totalLabel: (args['totalLabel'] as String?) ?? '',
            isPickup: (args['isPickup'] as bool?) ?? false,
          );
        },
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
        path: AppRoutes.customerProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const CustomerProfilePage(),
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
        path: AppRoutes.customerNotifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const CustomerNotificationsPage(),
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
        path: AppRoutes.customerPrivacy,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const LegalDocumentPage(kind: LegalDocumentKind.privacy),
      ),
      GoRoute(
        path: AppRoutes.customerTerms,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const LegalDocumentPage(kind: LegalDocumentKind.terms),
      ),
      GoRoute(
        path: '${AppRoutes.customerStoreDetails}/:storeId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) {
          final String storeId = state.pathParameters['storeId'] ?? '';
          final String storeName =
              state.uri.queryParameters['name'] ?? '';
          final String imageUrl = state.uri.queryParameters['imageUrl'] ?? '';
          final String tag = state.uri.queryParameters['tag'] ?? '';
          final String eta = state.uri.queryParameters['eta'] ?? '';
          final String deliveryFee =
              state.uri.queryParameters['deliveryFee'] ?? '';
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
      if (EnvConfig.includeAdminUi)
        GoRoute(
          path: AppRoutes.admin,
          builder: (BuildContext context, GoRouterState state) =>
              const AdminDashboardPage(),
        ),
    ],
  );
});
