# Localization progress (Sinhala / Tamil)

Tracks translation status for every file under `lib/features` in `mnd_customer`, so a
future pass can pick up where this one left off. Infrastructure (l10n.yaml, ARB files,
`AppLocalizations` wiring in `lib/app/app.dart`) is complete and working — this doc is
only about which *screens* have had their strings routed through it.

- **done** — hardcoded strings replaced with `AppLocalizations.of(context)` calls;
  `lib/l10n/app_{en,si,ta}.arb` all have matching keys.
- **excluded** — not in scope for customer-facing localization (operator-only UI, or a
  data/domain file with no UI at all).
- **pending** — not yet touched; still has hardcoded English strings (if any — most
  `data`/`domain`/`providers` files have no user-facing strings to begin with and will
  turn out to need no changes when picked up).
- **blocked** — has a specific architectural reason it can't be localized yet (see Notes).

Cross-check: `grep -rn "TODO(i18n" lib/features` finds the two blocked call sites
inline; everything else "pending" here has no such marker (there are simply too many
files to mark individually) — treat this table as the source of truth.

## Summary

| Status | Count |
|---|---|
| done | 18 |
| excluded | 19 |
| pending | 152 |

## admin/ — excluded (operator UI, gated by `EnvConfig.includeAdminUi` + admin role redirect in the router)

| File | Status |
|---|---|
| admin/data/admin_orders_repository.dart | excluded |
| admin/data/admin_product_cash_repository.dart | excluded |
| admin/data/admin_riders_repository.dart | excluded |
| admin/data/admin_withdrawals_repository.dart | excluded |
| admin/data/datasources/admin_remote_datasource.dart | excluded |
| admin/domain/entities/admin_profile.dart | excluded |
| admin/presentation/pages/admin_dashboard_page.dart | excluded |
| admin/presentation/pages/admin_job_approvals_page.dart | excluded |
| admin/presentation/pages/admin_jobs_page.dart | excluded |
| admin/presentation/pages/admin_orders_page.dart | excluded |
| admin/presentation/pages/admin_product_cash_page.dart | excluded |
| admin/presentation/pages/admin_riders_page.dart | excluded |
| admin/presentation/pages/admin_withdrawals_page.dart | excluded |
| admin/presentation/widgets/admin_dashboard_job_approvals_section.dart | excluded |
| admin/presentation/widgets/admin_job_approval_card.dart | excluded |

## auth/

| File | Status |
|---|---|
| auth/data/repositories/auth_repository_impl.dart | pending |
| auth/domain/entities/user.dart | pending |
| auth/domain/repositories/auth_repository.dart | pending |
| auth/domain/usecases/sign_in.dart | pending |
| **auth/presentation/pages/login_page.dart** | **done** |
| auth/presentation/pages/onboarding_page.dart | pending |
| auth/presentation/pages/splash_page.dart | pending |
| auth/presentation/pages/wrong_dedicated_app_page.dart | pending |
| auth/presentation/providers/guest_browsing_provider.dart | pending |
| auth/presentation/providers/phone_auth_controller.dart | pending |
| auth/presentation/providers/user_role_provider.dart | pending |
| auth/presentation/widgets/auth_slide_page.dart | pending |

## cart/

| File | Status |
|---|---|
| cart/domain/delivery_pricing.dart | pending |
| cart/domain/platform_fee_config.dart | pending |
| **cart/presentation/pages/cart_page.dart** | **done** |
| cart/presentation/providers/cart_provider.dart | pending |
| cart/presentation/providers/delivery_fee_quote_provider.dart | pending |
| cart/presentation/providers/platform_fee_config_provider.dart | pending |
| cart/presentation/providers/store_location_provider.dart | pending |
| cart/presentation/providers/store_pickup_info_provider.dart | pending |
| cart/presentation/widgets/floating_cart_summary_bar.dart | pending |

## checkout/

| File | Status |
|---|---|
| checkout/data/pending_checkout_store.dart | pending |
| **checkout/presentation/pages/checkout_page.dart** | **done** |
| **checkout/presentation/pages/order_confirmation_page.dart** | **done** |

## customer/

| File | Status |
|---|---|
| customer/data/customer_live_location_service.dart | pending |
| customer/data/customer_notifications_repository.dart | pending |
| customer/data/customer_profile_repository.dart | pending |
| customer/data/datasources/customer_remote_datasource.dart | pending |
| customer/data/notification_settings_repository.dart | pending |
| customer/data/saved_address.dart | pending |
| customer/domain/entities/customer_notification.dart | pending |
| customer/domain/entities/customer_profile.dart | pending |
| customer/domain/entities/notification_settings.dart | pending |
| customer/domain/profile_update_result.dart | pending |
| customer/presentation/pages/customer_favorites_page.dart | pending |
| customer/presentation/pages/customer_home_page.dart | pending (no literal strings — pure composer; see home/ widgets below) |
| customer/presentation/pages/customer_notifications_page.dart | pending |
| customer/presentation/pages/customer_profile_page.dart | pending |
| customer/presentation/pages/customer_search_page.dart | pending |
| **customer/presentation/pages/customer_settings_page.dart** | **done** |
| customer/presentation/pages/customer_shell_page.dart | pending (no literal strings) |
| customer/presentation/pages/customer_shops_page.dart | pending |
| customer/presentation/pages/edit_customer_profile_page.dart | pending |
| customer/presentation/pages/food_products_page.dart | pending |
| customer/presentation/pages/grocery_products_page.dart | pending |
| **customer/presentation/pages/language_selector_page.dart** | **done** |
| customer/presentation/pages/legal_document_page.dart | pending (recommend a dedicated legal-review pass regardless of this checklist) |
| customer/presentation/pages/notification_settings_page.dart | pending |
| customer/presentation/pages/saved_addresses_page.dart | pending |
| customer/presentation/providers/customer_banners_provider.dart | pending |
| customer/presentation/providers/customer_live_location_provider.dart | pending |
| customer/presentation/providers/customer_notifications_provider.dart | pending |
| customer/presentation/providers/customer_profile_provider.dart | pending |
| customer/presentation/providers/customer_search_provider.dart | pending |
| customer/presentation/providers/food_catalog_provider.dart | pending |
| customer/presentation/providers/grocery_catalog_provider.dart | pending |
| customer/presentation/providers/home_recent_searches_provider.dart | pending |
| customer/presentation/providers/home_recommended_provider.dart | pending |
| customer/presentation/providers/notification_settings_provider.dart | pending |
| customer/presentation/providers/saved_addresses_provider.dart | pending |
| customer/presentation/widgets/address_form_dialog.dart | pending |
| customer/presentation/widgets/customer_home_header.dart | pending |
| customer/presentation/widgets/customer_profile_avatar.dart | pending |
| customer/presentation/widgets/delivery_map_pick_result.dart | pending |
| customer/presentation/widgets/delivery_map_picker_page.dart | pending |
| **customer/presentation/widgets/floating_glass_nav_bar.dart** | **done** |
| customer/presentation/widgets/food/food_category_chips.dart | pending |
| customer/presentation/widgets/food/food_dish_shortcuts.dart | pending |
| customer/presentation/widgets/food/food_nearby_shops_section.dart | pending |
| customer/presentation/widgets/food/food_page_search_bar.dart | pending |
| customer/presentation/widgets/food/food_popular_section.dart | pending |
| customer/presentation/widgets/grocery/grocery_category_chips.dart | pending |
| customer/presentation/widgets/grocery/grocery_nearby_shops_section.dart | pending |
| customer/presentation/widgets/grocery/grocery_page_search_bar.dart | pending |
| customer/presentation/widgets/grocery/grocery_popular_section.dart | pending |
| **customer/presentation/widgets/home/add_to_home_screen_banner.dart** | **done** |
| **customer/presentation/widgets/home/home_category_rail.dart** | **done** |
| **customer/presentation/widgets/home/home_dispatch_hero.dart** | **done** |
| **customer/presentation/widgets/home/home_navigation_helpers.dart** | **done** (except `catalogLoadErrorMessage` — see blocked list) |
| **customer/presentation/widgets/home/home_nearby_shops_section.dart** | **done** |
| **customer/presentation/widgets/home/home_recently_ordered_section.dart** | **done** |
| **customer/presentation/widgets/home/home_recommended_section.dart** | **done** |
| **customer/presentation/widgets/home/home_search_bar.dart** | **done** |
| customer/presentation/widgets/mnd_shop_card.dart | pending |
| customer/presentation/widgets/product_card.dart | pending |
| customer/presentation/widgets/store/store_offers_section.dart | pending |

## jobs/ — deferred (not this pass)

| File | Status |
|---|---|
| jobs/data/jobs_repository.dart | pending |
| jobs/domain/entities/job_application.dart | pending |
| jobs/domain/entities/job_listing.dart | pending |
| jobs/domain/job_constants.dart | pending |
| jobs/presentation/pages/customer_jobs_menu_page.dart | pending |
| jobs/presentation/pages/job_applications_page.dart | pending |
| jobs/presentation/pages/job_detail_page.dart | pending |
| jobs/presentation/pages/jobs_home_page.dart | pending |
| jobs/presentation/pages/my_job_applications_page.dart | pending |
| jobs/presentation/pages/my_job_posts_page.dart | pending |
| jobs/presentation/pages/post_job_page.dart | pending |
| jobs/presentation/pages/saved_jobs_page.dart | pending |
| jobs/presentation/providers/jobs_providers.dart | pending |
| jobs/presentation/widgets/job_application_card.dart | pending |
| jobs/presentation/widgets/job_booked_badge.dart | pending |
| jobs/presentation/widgets/job_card.dart | pending |
| jobs/presentation/widgets/job_membership_gate.dart | pending |
| jobs/presentation/widgets/job_owner_applicants_banner.dart | pending |
| jobs/presentation/widgets/job_quick_apply_sheet.dart | pending |
| jobs/presentation/widgets/jobs_category_chips.dart | pending |
| jobs/presentation/widgets/jobs_filter_sheet.dart | pending |
| jobs/presentation/widgets/jobs_flow_widgets.dart | pending |
| jobs/presentation/widgets/jobs_horizontal_section.dart | pending |
| jobs/presentation/widgets/jobs_search_header.dart | pending |

## offers/

| File | Status |
|---|---|
| offers/domain/customer_offer.dart | pending |
| offers/presentation/offer_order_helpers.dart | pending |
| offers/presentation/providers/customer_offers_provider.dart | pending |

## orders/

| File | Status |
|---|---|
| orders/data/customer_order_rider_contact_repository.dart | pending |
| orders/data/customer_orders_repository.dart | pending (calls the blocked `userFacingError()` — see blocked list) |
| orders/data/order_placement_repository.dart | pending |
| orders/domain/entities/customer_order_detail.dart | pending |
| orders/domain/entities/customer_order_summary.dart | pending |
| orders/domain/entities/rider_live_location.dart | pending |
| orders/domain/order_cancellation.dart | pending |
| orders/domain/order_timeline.dart | pending |
| orders/domain/order_tracking_number.dart | pending |
| orders/domain/reorder_cart_mapper.dart | pending |
| **orders/presentation/pages/live_rider_tracking_page.dart** | **done** |
| **orders/presentation/pages/order_details_page.dart** | **done** |
| **orders/presentation/pages/orders_history_page.dart** | **done** |
| orders/presentation/providers/customer_orders_provider.dart | pending |
| orders/presentation/providers/order_detail_provider.dart | pending |
| orders/presentation/providers/order_placement_repository_provider.dart | pending |
| orders/presentation/providers/rider_live_location_provider.dart | pending |
| orders/presentation/utils/orders_load_error.dart | pending |
| orders/presentation/utils/reorder_helper.dart | pending |
| orders/presentation/widgets/animated_order_status_tracker.dart | pending |
| orders/presentation/widgets/cancel_order_bottom_sheet.dart | pending |
| orders/presentation/widgets/order_contact_actions.dart | pending |
| orders/presentation/widgets/rider_eta_countdown.dart | pending |
| orders/presentation/widgets/rider_rating_card.dart | pending |
| orders/presentation/widgets/store_rating_card.dart | pending |

## rider/ & vendor/ — excluded (no presentation/pages directory; not reachable as customer-facing UI)

| File | Status |
|---|---|
| rider/data/datasources/rider_remote_datasource.dart | excluded |
| rider/domain/entities/rider_profile.dart | excluded |
| vendor/data/datasources/vendor_remote_datasource.dart | excluded |
| vendor/domain/entities/vendor_profile.dart | excluded |

## rides/ — deferred (not this pass)

| File | Status |
|---|---|
| rides/data/customer_trip_rider_contact_repository.dart | pending |
| rides/data/ride_directions_service.dart | pending |
| rides/data/rides_repository.dart | pending |
| rides/domain/entities/online_ride_rider.dart | pending |
| rides/domain/entities/ride_place.dart | pending |
| rides/domain/entities/ride_trip.dart | pending |
| rides/domain/ride_constants.dart | pending |
| rides/domain/ride_distance.dart | pending |
| rides/presentation/pages/rides_booking_page.dart | pending |
| rides/presentation/pages/rides_confirm_page.dart | pending |
| rides/presentation/pages/rides_history_page.dart | pending |
| rides/presentation/pages/rides_live_tracking_page.dart | pending |
| rides/presentation/pages/rides_place_picker_page.dart | pending |
| rides/presentation/pages/rides_searching_page.dart | pending |
| rides/presentation/providers/ride_quotes_provider.dart | pending |
| rides/presentation/providers/ride_route_provider.dart | pending |
| rides/presentation/providers/rides_providers.dart | pending |
| rides/presentation/ride_status_style.dart | pending |
| rides/presentation/rides_map_markers.dart | pending |
| rides/presentation/rides_map_support.dart | pending |
| rides/presentation/rides_theme.dart | pending |
| rides/presentation/widgets/ride_completed_card.dart | pending |
| rides/presentation/widgets/ride_in_progress_card.dart | pending |
| rides/presentation/widgets/rides_map_controls.dart | pending |
| rides/presentation/widgets/rides_vehicle_card.dart | pending |
| rides/presentation/widgets/rides_vehicle_icon.dart | pending |

## store/

| File | Status |
|---|---|
| store/domain/product_availability.dart | pending |
| store/presentation/pages/store_details_page.dart | pending |
| store/presentation/widgets/product_details_bottom_sheet.dart | pending |

## support/

| File | Status |
|---|---|
| support/data/support_repository.dart | pending |
| support/domain/entities/support_message.dart | pending |
| support/presentation/pages/support_chat_page.dart | pending |

## Blocked (architectural, not just "not gotten to yet")

| File | Why |
|---|---|
| `core/utils/user_facing_error.dart` | Pure function with no `BuildContext`, called from 36 data-layer files (see `orders/data/customer_orders_repository.dart` etc.) that bake its English fallback strings into `Result` objects the UI displays verbatim. Needs a refactor to structured error enums (repository returns an enum; only the UI layer — which has `BuildContext` — translates it) before it can be localized. Marked `// TODO(i18n-blocked)` at the one in-scope call site that surfaced this (`customer/presentation/widgets/home/home_navigation_helpers.dart`'s `catalogLoadErrorMessage`). |

## Other files touched (infrastructure, outside `lib/features`)

- `lib/app/app.dart` — wired `AppLocalizations.delegate`.
- `lib/app/providers/locale_provider.dart` — `describeAppLocaleChoice()` now takes `BuildContext` to translate the "Device default" label (language names themselves stay in their own script).
- `lib/core/locale/app_language_option.dart` — sync-reminder comment only, no logic change.
