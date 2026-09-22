import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/services/analytics_service.dart';
import 'package:mnd_delivery_app/core/utils/delivery_address_resolver.dart';
import 'package:mnd_delivery_app/core/utils/payhere_native_launcher.dart';
import 'package:mnd_delivery_app/core/utils/vendor_open_hours.dart';
import 'package:mnd_delivery_app/features/cart/domain/delivery_pricing.dart';
import 'package:mnd_delivery_app/features/cart/domain/platform_fee_config.dart';
import 'package:mnd_delivery_app/features/cart/data/coupon_repository.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/coupon_repository_provider.dart';
import 'package:mnd_delivery_app/features/checkout/data/pending_checkout_store.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/delivery_fee_quote_provider.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/platform_fee_config_provider.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/store_pickup_info_provider.dart';
import 'package:mnd_delivery_app/features/orders/data/order_placement_repository.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/order_placement_repository_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_pick_result.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_picker_page.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/core/widgets/map_unavailable_banner.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_empty_state.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_expandable_card.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/core/utils/money_format.dart';
import 'package:mnd_delivery_app/core/utils/phone_number_utils.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/l10n/generated/app_localizations.dart';

enum CheckoutPaymentMethod {
  cashOnDelivery,
  payhere,
}

enum CheckoutOrderType {
  standard,
  emergency,
  schedule,
}

extension on CheckoutOrderType {
  /// Value written to the order doc / sent to the placement callables —
  /// matches the strings `resolveCheckoutOrderType` in
  /// `functions/src/checkoutOrderType.ts` expects.
  String get wireValue => switch (this) {
        CheckoutOrderType.standard => 'standard',
        CheckoutOrderType.emergency => 'emergency',
        CheckoutOrderType.schedule => 'schedule',
      };
}

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final TextEditingController _line1Controller = TextEditingController();
  final TextEditingController _line2Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _deliveryNoteController = TextEditingController();
  final TextEditingController _specialInstructionController =
      TextEditingController();
  CheckoutPaymentMethod _payment = CheckoutPaymentMethod.cashOnDelivery;
  CheckoutOrderType _orderType = CheckoutOrderType.standard;
  DateTime? _scheduledFor;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _placingOrder = false;

  /// Guards the very top of [_onPlaceOrder] against a fast double-tap firing
  /// it twice concurrently before the first call's `setState` (which drives
  /// the bottom bar's disabled state) has actually rebuilt the button —
  /// `_placingOrder` alone isn't set until partway through validation.
  bool _onPlaceOrderInFlight = false;

  /// Set when this checkout was restored from a saved pending-checkout
  /// snapshot (see [PendingCheckoutStore]) — i.e. the customer likely just
  /// came back from an abandoned/interrupted PayHere redirect. Shown as a
  /// dismissible note pointing at the earlier attempt, since it may still
  /// complete on its own via the payment webhook.
  PendingCheckoutSnapshot? _resumedFrom;

  /// True while silently resolving the customer's GPS position into a
  /// delivery address on first entering checkout — see
  /// [_tryAutoLocateIfNeeded]. Drives the loading overlay on the map preview.
  bool _autoLocating = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    final CartState cart = ref.read(cartProvider);
    _deliveryNoteController.text = cart.deliveryNote;
    _specialInstructionController.text = cart.specialInstructions;
    if (cart.isSelfPickup) {
      _payment = CheckoutPaymentMethod.payhere;
    }
    if (cart.isEmpty) {
      // A full browser reload (e.g. "back" from PayHere's hosted checkout on
      // web) wipes the in-memory cart — try to resume whatever the customer
      // was checking out instead of showing an empty cart / bouncing home.
      // Auto-locate only after that resume settles, so it never races a
      // restored address into overwriting it.
      _tryResumePendingCheckout().then((_) => _tryAutoLocateIfNeeded());
    } else {
      _tryAutoLocateIfNeeded();
    }
  }

  /// Silently grabs the customer's current GPS position and resolves it into
  /// a delivery address the moment they land on checkout with no address
  /// picked yet — so the map preview shows something useful immediately
  /// instead of an empty "pick on map" prompt. Never surfaces a permission
  /// error: if location is off/denied/slow, the customer can still set an
  /// address by hand via "Pick on map" or a saved address.
  Future<void> _tryAutoLocateIfNeeded() async {
    if (!mounted || !isDeliveryMapPickerSupported()) {
      return;
    }
    final CartState cart = ref.read(cartProvider);
    if (cart.isSelfPickup || _hasSelectedAddress) {
      return;
    }
    setState(() => _autoLocating = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      ).onError<TimeoutException>((_, __) async {
        final Position? last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return last;
        }
        throw TimeoutException('Location request timed out.');
      });
      if (!mounted || _hasSelectedAddress) {
        // The customer picked an address by hand while this was resolving.
        return;
      }
      final DeliveryMapPickResult resolved =
          await resolveDeliveryAddressForPoint(
        LatLng(position.latitude, position.longitude),
      );
      if (!mounted || _hasSelectedAddress) {
        return;
      }
      // Always non-null: this came from resolveDeliveryAddressForPoint,
      // which only ever geocodes a real GPS fix, never a saved address.
      ref
          .read(cartProvider.notifier)
          .setDropoffLocation(resolved.latitude!, resolved.longitude!);
      setState(() {
        _line1Controller.text = resolved.line1;
        _line2Controller.text = resolved.line2;
        _cityController.text = resolved.city;
      });
    } catch (_) {
      // Silent — the customer can still set an address with "Pick on map".
    } finally {
      if (mounted) {
        setState(() => _autoLocating = false);
      }
    }
  }

  Future<void> _tryResumePendingCheckout() async {
    final PendingCheckoutSnapshot? snapshot = await PendingCheckoutStore.peek();
    if (snapshot == null || !mounted) {
      return;
    }
    // Only restore into a still-empty cart — never clobber items the
    // customer has since added normally.
    if (!ref.read(cartProvider).isEmpty) {
      await PendingCheckoutStore.clear();
      return;
    }
    final CartNotifier cartNotifier = ref.read(cartProvider.notifier);
    cartNotifier.replaceCartContents(
      snapshot.items,
      deliveryNote: snapshot.deliveryNote,
      specialInstructions: snapshot.specialInstructions,
      dropoffLatitude: snapshot.dropoffLatitude,
      dropoffLongitude: snapshot.dropoffLongitude,
    );
    cartNotifier.setFulfillmentMode(snapshot.fulfillmentMode);
    if (snapshot.couponCode != null && snapshot.couponCode!.isNotEmpty) {
      // Re-validate against the server rather than trusting the snapshot —
      // the coupon may have expired or hit its usage limit since it was
      // applied. A silent failure here just leaves it unapplied; the coupon
      // code is still restored into the text field below for a manual retry.
      final CartState resumedCart = ref.read(cartProvider);
      final CouponValidationResult result =
          await ref.read(couponRepositoryProvider).validate(
                code: snapshot.couponCode!,
                subtotalLkr: resumedCart.subtotal,
                storeId: resumedCart.items.isEmpty
                    ? ''
                    : resumedCart.items.first.storeId,
              );
      if (result.isSuccess && mounted) {
        cartNotifier.setCoupon(result.coupon!);
      }
    }
    await PendingCheckoutStore.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _line1Controller.text = snapshot.addressLine1;
      _line2Controller.text = snapshot.addressLine2;
      _cityController.text = snapshot.city;
      _phoneController.text = snapshot.phone;
      _couponController.text = snapshot.couponCode ?? '';
      _deliveryNoteController.text = snapshot.deliveryNote;
      _specialInstructionController.text = snapshot.specialInstructions;
      // Self-pickup is online-payment-only app-wide; delivery defaults back
      // to Cash on delivery so an interrupted online payment always has a
      // working fallback.
      _payment = snapshot.fulfillmentMode == FulfillmentMode.selfPickup
          ? CheckoutPaymentMethod.payhere
          : CheckoutPaymentMethod.cashOnDelivery;
      _resumedFrom = snapshot;
    });
  }

  void _onPhoneChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _couponController.dispose();
    _deliveryNoteController.dispose();
    _specialInstructionController.dispose();
    super.dispose();
  }

  /// When non-null, place order must stay disabled (sign-in only).
  /// Firestore rules enforce [validOrderCreate] (including customerId == auth uid).
  static String? _placeOrderBlockReason(
    BuildContext context,
    AsyncValue<User?> authAsync,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (authAsync.isLoading) {
      return l10n.checkoutCheckingSignIn;
    }
    if (authAsync.hasError) {
      return l10n.checkoutSignInStateError;
    }
    final User? user = authAsync.value;
    if (user == null) {
      return l10n.checkoutSignInRequired;
    }
    return null;
  }

  bool get _hasSelectedAddress {
    return _line1Controller.text.trim().isNotEmpty &&
        _cityController.text.trim().isNotEmpty;
  }

  String _resolvedPhone() {
    final String typed = _phoneController.text.trim();
    if (typed.isNotEmpty) {
      return typed;
    }
    return ref.read(customerProfileStreamProvider).valueOrNull?.phone.trim() ??
        '';
  }

  bool _phoneLooksUsable(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '').length >= 8;
  }

  bool get _hasResolvablePhone => _phoneLooksUsable(_resolvedPhone());

  /// Display / confirm fee: distance when pinned; flat fallback when address
  /// without pin so delivery is not free at submit.
  int _deliveryFeeForOrder(CartState cart, DeliveryFeeQuote quote) {
    if (cart.isSelfPickup) {
      return 0;
    }
    final bool hasPin =
        cart.dropoffLatitude != null && cart.dropoffLongitude != null;
    if (hasPin) {
      return quote.feeLkr;
    }
    if (quote.feeLkr > 0) {
      return quote.feeLkr;
    }
    return DeliveryPricing.fallbackFlatLkr;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<User?> authAsync = ref.watch(authStateUserProvider);
    final String? placeOrderBlock = _placeOrderBlockReason(context, authAsync);
    // Rebuild when profile phone becomes available for Place order enablement.
    ref.watch(customerProfileStreamProvider);

    final CartState cart = ref.watch(cartProvider);
    final DeliveryFeeQuote deliveryQuote = ref.watch(deliveryFeeQuoteProvider);
    final PlatformFeeConfig feeConfig =
        ref.watch(platformFeeConfigProvider).valueOrNull ??
            const PlatformFeeConfig.defaults();
    final bool isPickup = cart.isSelfPickup;

    if (cart.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.backgroundCanvas,
        appBar: mndPageAppBar(title: l10n.checkoutTitle),
        body: MndEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: l10n.checkoutEmptyTitle,
          subtitle: l10n.checkoutEmptySubtitle,
          actionLabel: l10n.homeHeroOrderFood,
          onAction: () => context.go(AppRoutes.customerFood),
        ),
      );
    }

    final int subtotal = cart.subtotal;
    final int discount = cart.discount;
    final bool hasMapPin =
        cart.dropoffLatitude != null && cart.dropoffLongitude != null;
    // Keep summary total aligned with place-order fee (incl. flat fallback).
    final int deliveryFee = _deliveryFeeForOrder(cart, deliveryQuote);
    final int serviceCharge = ServiceChargePricing.serviceChargeLkr(
      subtotal,
      percentOverride: feeConfig.serviceChargePercent,
    );
    final int emergencyFee = _orderType == CheckoutOrderType.emergency
        ? feeConfig.emergencyFeeLkr
        : 0;
    final bool payingOnline = _payment == CheckoutPaymentMethod.payhere;
    final int ipgFee = payingOnline
        ? IpgFeePricing.ipgFeeLkr(
            subtotal - discount + deliveryFee + serviceCharge + emergencyFee,
            percentOverride: feeConfig.ipgFeePercent,
          )
        : 0;
    final int total = subtotal -
        discount +
        deliveryFee +
        serviceCharge +
        emergencyFee +
        ipgFee;
    final String storeId = cart.items.first.storeId;

    final bool missingDeliveryAddress = !isPickup && !_hasSelectedAddress;
    // A saved address without a stored pin still needs one picked on the map
    // so the delivery fee isn't always the flat estimate.
    final bool missingMapPin = !isPickup && _hasSelectedAddress && !hasMapPin;
    final bool missingPhone = !_hasResolvablePhone;
    final bool missingScheduledTime =
        _orderType == CheckoutOrderType.schedule && _scheduledFor == null;
    final String? readinessHint = placeOrderBlock != null
        ? null
        : missingDeliveryAddress
            ? l10n.checkoutHintAddAddress
            : missingMapPin
                ? l10n.checkoutHintPinAddress
                : missingPhone
                    ? l10n.checkoutHintAddPhone
                    : missingScheduledTime
                        ? l10n.checkoutScheduleRequiredWarning
                        : null;
    final bool placeOrderDisabled = _placingOrder ||
        placeOrderBlock != null ||
        missingScheduledTime ||
        missingDeliveryAddress ||
        missingPhone;

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(title: l10n.checkoutTitle),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_resumedFrom != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: MndPremiumCard(
                          borderRadius: AppColors.cardRadiusSm,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(
                                Icons.history_rounded,
                                color: AppColors.brandPrimary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      l10n.checkoutResumedTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _resumedFrom!.pendingTrackingNumber !=
                                              null
                                          ? l10n
                                              .checkoutResumedWithTrackingMessage(
                                              _resumedFrom!
                                                  .pendingTrackingNumber!,
                                            )
                                          : l10n.checkoutResumedMessage,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    if (_resumedFrom!.pendingOrderId !=
                                        null) ...<Widget>[
                                      const SizedBox(height: 4),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => context.push(
                                          '${AppRoutes.customerOrders}/${_resumedFrom!.pendingOrderId}',
                                        ),
                                        child: Text(l10n.actionCheckThatOrder),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (placeOrderBlock != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: placeOrderBlock == l10n.checkoutSignInRequired
                            ? const SignInRequiredBanner()
                            : MndPremiumCard(
                                borderRadius: AppColors.cardRadiusSm,
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Icon(
                                      Icons.info_outline,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        placeOrderBlock,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    _CheckoutHeroCard(
                      fulfillmentMode: cart.fulfillmentMode,
                      onFulfillmentChanged: (FulfillmentMode mode) {
                        ref
                            .read(cartProvider.notifier)
                            .setFulfillmentMode(mode);
                        if (mode == FulfillmentMode.selfPickup) {
                          setState(() {
                            _payment = CheckoutPaymentMethod.payhere;
                            // Emergency (rush delivery) doesn't apply once
                            // the customer is collecting it themselves.
                            if (_orderType == CheckoutOrderType.emergency) {
                              _orderType = CheckoutOrderType.standard;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _OrderTypeSection(
                      storeId: storeId,
                      orderType: _orderType,
                      isPickup: isPickup,
                      scheduledFor: _scheduledFor,
                      onOrderTypeChanged: (CheckoutOrderType type) {
                        setState(() {
                          _orderType = type;
                          if (type != CheckoutOrderType.schedule) {
                            _scheduledFor = null;
                          }
                        });
                      },
                      onPickScheduledTime: _pickScheduledTime,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (isPickup)
                      _PickupFulfillmentSection(
                        storeId: storeId,
                      )
                    else
                      _DeliveryFulfillmentSection(
                        hasSelectedAddress: _hasSelectedAddress,
                        latitude: cart.dropoffLatitude,
                        longitude: cart.dropoffLongitude,
                        autoLocating: _autoLocating,
                        line1Controller: _line1Controller,
                        line2Controller: _line2Controller,
                        cityController: _cityController,
                        onManageTap: () =>
                            context.push(AppRoutes.customerSavedAddresses),
                        onMapTap: _openDeliveryMapPicker,
                      ),
                    const SizedBox(height: AppSpacing.md),
                    MndSectionHeader(title: l10n.checkoutOrderOptionsHeader),
                    const SizedBox(height: AppSpacing.sm),
                    _CheckoutCouponCard(controller: _couponController),
                    const SizedBox(height: AppSpacing.sm),
                    _CheckoutDeliveryInstructionsCard(
                      deliveryNoteController: _deliveryNoteController,
                      specialInstructionController:
                          _specialInstructionController,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    MndPremiumCard(
                      borderRadius: AppColors.cardRadiusSm,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: TextFormField(
                        key: const ValueKey<String>('checkoutPhoneField'),
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: l10n.checkoutContactPhoneLabel,
                          hintText: l10n.checkoutContactPhoneHint,
                        ),
                        keyboardType: TextInputType.phone,
                        maxLength: 20,
                        buildCounter: _collapsedCounter,
                        validator: (String? v) {
                          final String t = v?.trim() ?? '';
                          if (t.isEmpty) {
                            return null;
                          }
                          return PhoneNumberUtils.validateNationalNumber(
                            dialCode: '+94',
                            nationalNumber: v,
                          )?.message(l10n);
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MndSectionHeader(title: l10n.checkoutPaymentMethodHeader),
                    const SizedBox(height: AppSpacing.sm),
                    MndPremiumCard(
                      borderRadius: AppColors.cardRadiusSm,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              if (!isPickup) ...<Widget>[
                                Expanded(
                                  child: _PaymentChip(
                                    label: l10n.paymentCashOnDelivery,
                                    icon: Icons.payments_outlined,
                                    selected: _payment ==
                                        CheckoutPaymentMethod.cashOnDelivery,
                                    enabled: true,
                                    onTap: () => setState(
                                      () => _payment =
                                          CheckoutPaymentMethod.cashOnDelivery,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                              ],
                              Expanded(
                                child: _PaymentChip(
                                  label: l10n.paymentPayOnline,
                                  icon: Icons.credit_card_rounded,
                                  selected:
                                      _payment == CheckoutPaymentMethod.payhere,
                                  enabled: true,
                                  onTap: () => setState(
                                    () => _payment =
                                        CheckoutPaymentMethod.payhere,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            isPickup
                                ? l10n.checkoutPayOnlinePickupNote
                                : _payment == CheckoutPaymentMethod.payhere
                                    ? l10n.checkoutPayNowNote
                                    : l10n.checkoutPayCashNote,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MndSectionHeader(title: l10n.checkoutYourOrderHeader),
                    const SizedBox(height: AppSpacing.sm),
                    MndPremiumCard(
                      borderRadius: AppColors.cardRadiusSm,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (_orderType == CheckoutOrderType.schedule &&
                              _scheduledFor != null) ...<Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 16,
                                  color: AppColors.primaryBlue,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    l10n.checkoutConfirmScheduledNote(
                                      _formatScheduledFor(_scheduledFor!),
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.primaryBlue,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          _SummaryRow(
                            label: l10n.summarySubtotal,
                            value: MoneyFormat.lkr(subtotal),
                          ),
                          if (discount > 0) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            _SummaryRow(
                              label: l10n.summaryDiscount,
                              value: '- ${MoneyFormat.lkr(discount)}',
                              valueColor: AppColors.success,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          _SummaryRow(
                            label: isPickup
                                ? l10n.checkoutPickupLabel
                                : l10n.fulfillmentDelivery,
                            value: MoneyFormat.lkr(deliveryFee),
                            detail: _deliveryFeeDetailText(l10n, deliveryQuote),
                          ),
                          if (serviceCharge > 0) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            _SummaryRow(
                              label: l10n.checkoutServiceChargeLabel(
                                feeConfig.serviceChargePercentLabel,
                              ),
                              value: MoneyFormat.lkr(serviceCharge),
                            ),
                          ],
                          if (emergencyFee > 0) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            _SummaryRow(
                              label: l10n.summaryEmergencyFeeLabel,
                              value: MoneyFormat.lkr(emergencyFee),
                            ),
                          ],
                          if (ipgFee > 0) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            _SummaryRow(
                              label: l10n.checkoutBankFeeLabel(
                                feeConfig.ipgFeePercentLabel,
                              ),
                              value: MoneyFormat.lkr(ipgFee),
                            ),
                          ],
                          const Divider(height: AppSpacing.lg),
                          _SummaryRow(
                            label: l10n.cartTotalLabel,
                            value: MoneyFormat.lkr(total),
                            emphasize: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),
          _CheckoutBottomBar(
            totalLabel: MoneyFormat.lkr(total),
            isPlacingOrder: _placingOrder,
            blockedHint: placeOrderBlock ?? readinessHint,
            needsSignIn: placeOrderBlock == l10n.checkoutSignInRequired,
            onSignIn: placeOrderBlock == l10n.checkoutSignInRequired
                ? () => navigateToSignInForCheckout(ref, context)
                : null,
            onPlaceOrder:
                placeOrderDisabled ? null : () => _onPlaceOrder(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openDeliveryMapPicker() async {
    final DeliveryMapPickResult? pick =
        await DeliveryMapPickerPage.pick(context);
    if (pick == null || !mounted) {
      return;
    }
    final double? pickedLat = pick.latitude;
    final double? pickedLng = pick.longitude;
    if (pickedLat != null && pickedLng != null) {
      ref.read(cartProvider.notifier).setDropoffLocation(pickedLat, pickedLng);
    } else {
      // A saved address that was never pinned on the map — keep the text,
      // drop any previous pin so the delivery fee falls back to the flat
      // estimate rather than showing a stale distance-based one.
      ref.read(cartProvider.notifier).clearDropoffLocation();
    }
    setState(() {
      _line1Controller.text = pick.line1;
      _line2Controller.text = pick.line2;
      _cityController.text = pick.city;
      // Set only when the pick came from a saved address (see
      // DeliveryMapPickResult.phone) — a manual map pin or search result
      // never carries a phone, so this leaves the field untouched then.
      final String? phone = pick.phone;
      if (phone != null && phone.isNotEmpty) {
        _phoneController.text = phone;
      }
    });
  }

  /// Native date + time pickers for a "Schedule" order — bounded to today
  /// through the next 2 days (see `MAX_SCHEDULE_AHEAD_MS` in
  /// `functions/src/checkoutOrderType.ts`, which the server enforces
  /// authoritatively; this is just the UI's matching window).
  Future<void> _pickScheduledTime() async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _scheduledFor ?? now,
      firstDate: today,
      lastDate: today.add(const Duration(days: 2)),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _scheduledFor != null
          ? TimeOfDay.fromDateTime(_scheduledFor!)
          : TimeOfDay.fromDateTime(now.add(const Duration(minutes: 30))),
    );
    if (time == null || !mounted) {
      return;
    }
    final DateTime combined =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (combined.isBefore(now)) {
      showMndSnackBar(
        context,
        AppLocalizations.of(context).checkoutScheduledTimePastError,
        variant: MndSnackBarVariant.warning,
      );
      return;
    }
    setState(() => _scheduledFor = combined);
  }

  /// A closed shop can still take a Schedule order, so when the customer
  /// picked anything else, point them at that instead of a plain "closed".
  void _showShopClosedNotice(BuildContext context) {
    if (_orderType == CheckoutOrderType.schedule) {
      showShopClosedSnackBar(context);
      return;
    }
    showMndSnackBar(
      context,
      AppLocalizations.of(context).shopClosedScheduleHint,
      variant: MndSnackBarVariant.warning,
    );
  }

  Future<bool> _cartStoreIsAcceptingOrders(String storeId) async {
    final bool scheduled = _orderType == CheckoutOrderType.schedule;
    final String id = storeId.trim();
    if (id.isEmpty) {
      return false;
    }
    try {
      final snap = await ref
          .read(firestoreProvider)
          .collection(FirebaseCollections.vendors)
          .doc(id)
          .get();
      final Map<String, dynamic>? map = snap.data();
      if (map == null) {
        return false;
      }
      return vendorAcceptsOrders(map, scheduled: scheduled);
    } catch (_) {
      return false;
    }
  }

  Future<void> _onPlaceOrder(BuildContext context) async {
    if (_onPlaceOrderInFlight) {
      return;
    }
    _onPlaceOrderInFlight = true;
    try {
      await _onPlaceOrderInner(context);
    } finally {
      _onPlaceOrderInFlight = false;
    }
  }

  Future<void> _onPlaceOrderInner(BuildContext context) async {
    final String? block =
        _placeOrderBlockReason(context, ref.read(authStateUserProvider));
    if (block != null) {
      if (!context.mounted) {
        return;
      }
      showMndSnackBar(context, block, variant: MndSnackBarVariant.warning);
      return;
    }

    final CartState previewCart = ref.read(cartProvider);
    final bool isPickup = previewCart.isSelfPickup;

    if (isPickup && _payment != CheckoutPaymentMethod.payhere) {
      _payment = CheckoutPaymentMethod.payhere;
    }

    if (!isPickup && !_hasSelectedAddress) {
      if (!context.mounted) {
        return;
      }
      showMndSnackBar(
        context,
        AppLocalizations.of(context).checkoutPickAddressWarning,
        variant: MndSnackBarVariant.warning,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String phone = _resolvedPhone();
    if (!_phoneLooksUsable(phone)) {
      if (!context.mounted) {
        return;
      }
      showMndSnackBar(
        context,
        AppLocalizations.of(context).checkoutHintAddPhone,
        variant: MndSnackBarVariant.warning,
      );
      return;
    }
    final PhoneValidationError? typedPhoneError =
        _phoneController.text.trim().isEmpty
            ? null
            : PhoneNumberUtils.validateNationalNumber(
                dialCode: '+94',
                nationalNumber: _phoneController.text,
              );
    if (typedPhoneError != null) {
      if (!context.mounted) {
        return;
      }
      showMndSnackBar(
        context,
        typedPhoneError.message(AppLocalizations.of(context)),
        variant: MndSnackBarVariant.warning,
      );
      return;
    }

    final String previewStoreId =
        previewCart.isEmpty ? '' : previewCart.items.first.storeId;
    final bool storeOpen = await _cartStoreIsAcceptingOrders(previewStoreId);
    if (!storeOpen) {
      if (context.mounted) {
        _showShopClosedNotice(context);
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final DeliveryFeeQuote previewQuote = ref.read(deliveryFeeQuoteProvider);
    final PlatformFeeConfig previewFeeConfig =
        ref.read(platformFeeConfigProvider).valueOrNull ??
            const PlatformFeeConfig.defaults();
    final int previewDeliveryFee =
        _deliveryFeeForOrder(previewCart, previewQuote);
    final int previewServiceCharge = ServiceChargePricing.serviceChargeLkr(
      previewCart.subtotal,
      percentOverride: previewFeeConfig.serviceChargePercent,
    );
    final int previewEmergencyFee = _orderType == CheckoutOrderType.emergency
        ? previewFeeConfig.emergencyFeeLkr
        : 0;
    final int previewIpgFee = _payment == CheckoutPaymentMethod.payhere
        ? IpgFeePricing.ipgFeeLkr(
            previewCart.subtotal -
                previewCart.discount +
                previewDeliveryFee +
                previewServiceCharge +
                previewEmergencyFee,
            percentOverride: previewFeeConfig.ipgFeePercent,
          )
        : 0;
    final int previewTotal = previewCart.subtotal -
        previewCart.discount +
        previewDeliveryFee +
        previewServiceCharge +
        previewEmergencyFee +
        previewIpgFee;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => _PlaceOrderConfirmDialog(
        totalLabel: MoneyFormat.lkr(previewTotal),
        payment: _payment,
        isPickup: isPickup,
        scheduledForLabel:
            _orderType == CheckoutOrderType.schedule && _scheduledFor != null
                ? _formatScheduledFor(_scheduledFor!)
                : null,
      ),
    );

    if (confirm != true || !context.mounted) {
      return;
    }

    final CartState cart = ref.read(cartProvider);
    final DeliveryFeeQuote quote = ref.read(deliveryFeeQuoteProvider);
    if (cart.isEmpty) {
      showMndSnackBar(
        context,
        AppLocalizations.of(context).checkoutCartEmptyWarning,
        variant: MndSnackBarVariant.warning,
      );
      return;
    }

    final bool stillOpen =
        await _cartStoreIsAcceptingOrders(cart.items.first.storeId);
    if (!stillOpen) {
      if (context.mounted) {
        _showShopClosedNotice(context);
      }
      return;
    }
    if (!context.mounted) {
      return;
    }

    final int subtotal = cart.subtotal;
    final int discount = cart.discount;
    final int deliveryFee = _deliveryFeeForOrder(cart, quote);
    final PlatformFeeConfig submitFeeConfig =
        ref.read(platformFeeConfigProvider).valueOrNull ??
            const PlatformFeeConfig.defaults();
    final int serviceCharge = ServiceChargePricing.serviceChargeLkr(
      subtotal,
      percentOverride: submitFeeConfig.serviceChargePercent,
    );
    final int emergencyFee = _orderType == CheckoutOrderType.emergency
        ? submitFeeConfig.emergencyFeeLkr
        : 0;
    final int ipgFee = _payment == CheckoutPaymentMethod.payhere
        ? IpgFeePricing.ipgFeeLkr(
            subtotal - discount + deliveryFee + serviceCharge + emergencyFee,
            percentOverride: submitFeeConfig.ipgFeePercent,
          )
        : 0;
    final int total = subtotal -
        discount +
        deliveryFee +
        serviceCharge +
        emergencyFee +
        ipgFee;
    if (total < 0) {
      showMndSnackBar(
        context,
        AppLocalizations.of(context).checkoutInvalidTotalError,
        variant: MndSnackBarVariant.error,
      );
      return;
    }

    String addressLine1 = _line1Controller.text.trim();
    String addressLine2 = _line2Controller.text.trim();
    String city = _cityController.text.trim();

    if (cart.isSelfPickup) {
      final String storeId = cart.items.first.storeId;
      // Not localized: this becomes the order's stored addressLine1/city,
      // read by the rider and admin apps (not localized), not just displayed
      // here.
      final String fallbackStoreName =
          cart.items.first.storeName.trim().isNotEmpty
              ? cart.items.first.storeName.trim()
              : 'Store';
      StorePickupInfo? pickupInfo;
      try {
        pickupInfo =
            await ref.read(storePickupInfoByStoreIdProvider(storeId).future);
      } catch (_) {
        pickupInfo = null;
      }
      final String addressLine = pickupInfo?.addressLine.trim() ?? '';
      final String storeLabel = (pickupInfo?.name.trim().isNotEmpty ?? false)
          ? pickupInfo!.name.trim()
          : fallbackStoreName;
      addressLine1 = addressLine.isNotEmpty ? addressLine : storeLabel;
      addressLine2 = '';
      final String pickupCity = pickupInfo?.city.trim() ?? '';
      city = pickupCity.isNotEmpty ? pickupCity : 'Pickup';
    }

    setState(() => _placingOrder = true);
    try {
      final OrderPlacementRepository repo =
          ref.read(orderPlacementRepositoryProvider);

      if (_payment == CheckoutPaymentMethod.payhere) {
        await _placeOrderWithPayHere(
          context,
          repo: repo,
          cart: cart,
          addressLine1: addressLine1,
          addressLine2: addressLine2,
          city: city,
          phone: phone,
        );
        return;
      }

      final OrderPlacementResult result = await repo.placeCashOnDeliveryOrder(
        cart: cart,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        phone: phone,
        couponCode: cart.appliedCoupon?.code,
        orderType: _orderType.wireValue,
        scheduledFor: _scheduledFor?.toUtc().toIso8601String(),
      );

      if (!context.mounted) {
        return;
      }

      if (!result.isSuccess) {
        showMndSnackBar(
          context,
          result.errorMessage ??
              AppLocalizations.of(context).checkoutOrderFailedFallback,
          variant: MndSnackBarVariant.error,
        );
        return;
      }

      ref.read(cartProvider.notifier).clear();
      final String? tn = result.trackingNumber?.trim();
      final String? orderId = result.orderId;
      if (orderId != null && orderId.isNotEmpty) {
        unawaited(
          AnalyticsService.logOrderPlaced(
            orderId: orderId,
            totalLkr: total.toDouble(),
          ),
        );
        context.go(
          AppRoutes.customerOrderConfirmation,
          extra: <String, dynamic>{
            'orderId': orderId,
            'trackingNumber': tn,
            'totalLabel': MoneyFormat.lkr(total),
            'isPickup': cart.isSelfPickup,
          },
        );
      } else {
        showMndSnackBar(
          context,
          AppLocalizations.of(context).checkoutOrderPlacedSuccess,
          variant: MndSnackBarVariant.success,
        );
        context.go(AppRoutes.customerOrders);
      }
    } finally {
      if (mounted) {
        setState(() => _placingOrder = false);
      }
    }
  }

  /// Creates a draft order and collects payment in-app via PayHere's native
  /// SDK. The order becomes real once `payHereNotify` confirms payment
  /// server-side — this only reacts to the SDK's own completed/dismissed/
  /// error callback to decide whether to clear the cart and navigate.
  Future<void> _placeOrderWithPayHere(
    BuildContext context, {
    required OrderPlacementRepository repo,
    required CartState cart,
    required String addressLine1,
    required String addressLine2,
    required String city,
    required String phone,
  }) async {
    try {
      final OrderPayHereCheckout checkout =
          await repo.createPayHereCheckoutForOrder(
        cart: cart,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        phone: phone,
        couponCode: cart.appliedCoupon?.code,
        orderType: _orderType.wireValue,
        scheduledFor: _scheduledFor?.toUtc().toIso8601String(),
      );
      if (!context.mounted) {
        return;
      }
      if (kIsWeb) {
        // A web redirect fully unloads this page — save what's needed to
        // restore the cart/address/payment-method choice if the customer
        // comes back (e.g. taps the browser's back button) instead of
        // completing payment.
        await PendingCheckoutStore.save(
          PendingCheckoutSnapshot(
            items: cart.items,
            fulfillmentMode: cart.fulfillmentMode,
            deliveryNote: cart.deliveryNote,
            specialInstructions: cart.specialInstructions,
            dropoffLatitude: cart.dropoffLatitude,
            dropoffLongitude: cart.dropoffLongitude,
            couponCode: cart.appliedCoupon?.code,
            addressLine1: addressLine1,
            addressLine2: addressLine2,
            city: city,
            phone: phone,
            pendingOrderId: checkout.orderId,
            pendingTrackingNumber: checkout.trackingNumber,
            savedAt: DateTime.now(),
          ),
        );
      }
      final PayHereNativeResult result = await launchPayHerePayment(
        fields: checkout.fields,
        sandbox: checkout.sandbox,
        checkoutPageUrl: checkout.checkoutPageUrl,
      );
      if (!context.mounted) {
        return;
      }
      switch (result.status) {
        case PayHereNativeStatus.completed:
          await PendingCheckoutStore.clear();
          ref.read(cartProvider.notifier).clear();
          showMndSnackBar(
            context,
            AppLocalizations.of(context)
                .checkoutPaymentSuccessMessage(checkout.trackingNumber),
            variant: MndSnackBarVariant.success,
          );
          context.go('${AppRoutes.customerOrders}/${checkout.orderId}');
          break;
        case PayHereNativeStatus.opened:
          // The browser is navigating away to PayHere's checkout page — this
          // does NOT mean payment succeeded, only that the redirect started.
          // Deliberately does NOT clear the cart, the saved resume snapshot,
          // or navigate to the order: if the redirect completes, this whole
          // page unloads anyway and none of that would matter; if it doesn't
          // (e.g. the user backs out before PayHere's page finishes
          // loading), the cart and checkout screen must still be intact
          // rather than looking like the order already went through.
          showMndSnackBar(
            context,
            AppLocalizations.of(context)
                .checkoutRedirectingPaymentMessage(checkout.trackingNumber),
            variant: MndSnackBarVariant.success,
          );
          break;
        case PayHereNativeStatus.dismissed:
          await PendingCheckoutStore.clear();
          showMndSnackBar(
            context,
            AppLocalizations.of(context).checkoutPaymentCancelledMessage,
            variant: MndSnackBarVariant.warning,
          );
          break;
        case PayHereNativeStatus.error:
          // The redirect never actually happened, so there's nothing to
          // resume — drop the snapshot saved just above so a later visit
          // doesn't show a stale "resumed" note for it.
          await PendingCheckoutStore.clear();
          showMndSnackBar(
            context,
            result.errorMessage ??
                AppLocalizations.of(context).checkoutPaymentFailedFallback,
            variant: MndSnackBarVariant.error,
          );
          break;
      }
    } catch (e) {
      if (context.mounted) {
        showMndSnackBar(
          context,
          userFacingError(
            e,
            fallback: AppLocalizations.of(context).checkoutStartPaymentError,
          ),
          variant: MndSnackBarVariant.error,
        );
      }
    }
  }
}

class _PlaceOrderConfirmDialog extends StatelessWidget {
  const _PlaceOrderConfirmDialog({
    required this.totalLabel,
    required this.payment,
    required this.isPickup,
    this.scheduledForLabel,
  });

  final String totalLabel;
  final CheckoutPaymentMethod payment;
  final bool isPickup;

  /// Set only for a Schedule order — shown as an extra note under the
  /// payment description.
  final String? scheduledForLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isOnline = payment == CheckoutPaymentMethod.payhere;
    final String description = isOnline
        ? l10n.checkoutConfirmPayOnline(totalLabel)
        : isPickup
            ? l10n.checkoutConfirmPayPickup(totalLabel)
            : l10n.checkoutConfirmPayCash(totalLabel);

    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOnline
                    ? Icons.credit_card_rounded
                    : Icons.receipt_long_rounded,
                color: AppColors.brandPrimary,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.checkoutConfirmTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              totalLabel,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.brandPrimary,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (scheduledForLabel != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                l10n.checkoutConfirmScheduledNote(scheduledForLabel!),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm + 2),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppColors.buttonRadius),
                      ),
                      side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.12)),
                      foregroundColor: AppColors.textPrimary,
                    ),
                    child: Text(l10n.actionCancel),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm + 2),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppColors.buttonRadius),
                      ),
                    ),
                    child: Text(l10n.actionConfirm),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutHeroCard extends StatelessWidget {
  const _CheckoutHeroCard({
    required this.fulfillmentMode,
    required this.onFulfillmentChanged,
  });

  final FulfillmentMode fulfillmentMode;
  final ValueChanged<FulfillmentMode> onFulfillmentChanged;

  @override
  Widget build(BuildContext context) {
    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusSm,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: _FulfillmentModeSegment(
        mode: fulfillmentMode,
        onChanged: onFulfillmentChanged,
      ),
    );
  }
}

class _OrderTypeSection extends ConsumerWidget {
  const _OrderTypeSection({
    required this.storeId,
    required this.orderType,
    required this.isPickup,
    required this.scheduledFor,
    required this.onOrderTypeChanged,
    required this.onPickScheduledTime,
  });

  final String storeId;
  final CheckoutOrderType orderType;
  final bool isPickup;
  final DateTime? scheduledFor;
  final ValueChanged<CheckoutOrderType> onOrderTypeChanged;
  final VoidCallback onPickScheduledTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<StorePickupInfo?> pickupInfoAsync =
        ref.watch(storePickupInfoByStoreIdProvider(storeId));
    final VendorOpeningHours openingHours = VendorOpeningHours.fromRaw(
      pickupInfoAsync.valueOrNull?.openingHours,
    );
    final bool outsideHours =
        scheduledFor != null && !openingHours.isOpenAt(scheduledFor!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MndSectionHeader(title: l10n.checkoutOrderTypeHeader),
        const SizedBox(height: AppSpacing.sm),
        MndPremiumCard(
          borderRadius: AppColors.cardRadiusSm,
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _PaymentChip(
                      label: l10n.checkoutOrderTypeStandard,
                      icon: Icons.local_shipping_outlined,
                      selected: orderType == CheckoutOrderType.standard,
                      enabled: true,
                      onTap: () =>
                          onOrderTypeChanged(CheckoutOrderType.standard),
                    ),
                  ),
                  if (!isPickup) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _PaymentChip(
                        label: l10n.checkoutOrderTypeEmergency,
                        icon: Icons.bolt_rounded,
                        selected: orderType == CheckoutOrderType.emergency,
                        enabled: true,
                        onTap: () =>
                            onOrderTypeChanged(CheckoutOrderType.emergency),
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _PaymentChip(
                      label: l10n.checkoutOrderTypeSchedule,
                      icon: Icons.event_outlined,
                      selected: orderType == CheckoutOrderType.schedule,
                      enabled: true,
                      onTap: () =>
                          onOrderTypeChanged(CheckoutOrderType.schedule),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                switch (orderType) {
                  CheckoutOrderType.standard =>
                    l10n.checkoutOrderTypeStandardNote,
                  CheckoutOrderType.emergency =>
                    l10n.checkoutOrderTypeEmergencyNote,
                  CheckoutOrderType.schedule =>
                    l10n.checkoutOrderTypeScheduleNote,
                },
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (orderType == CheckoutOrderType.schedule) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Material(
                  color: AppColors.primaryBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
                  child: InkWell(
                    onTap: onPickScheduledTime,
                    borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppColors.cardRadiusSm),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              scheduledFor == null
                                  ? l10n.checkoutSchedulePickTimeCta
                                  : l10n.checkoutScheduledForLabel(
                                      _formatScheduledFor(scheduledFor!),
                                    ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.primaryBlue.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (outsideHours) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    l10n.checkoutScheduleOutsideHoursWarning,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// e.g. "Jan 5, 6:30 PM" — a fixed pattern rather than locale-aware
/// formatting, matching this app's other hand-rolled formatters (see
/// [MoneyFormat]) rather than pulling in `intl`'s `DateFormat`.
String _formatScheduledFor(DateTime dt) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  final int hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final String period = dt.hour < 12 ? 'AM' : 'PM';
  final String minute = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, $hour12:$minute $period';
}

class _FulfillmentModeSegment extends StatelessWidget {
  const _FulfillmentModeSegment({
    required this.mode,
    required this.onChanged,
  });

  final FulfillmentMode mode;
  final ValueChanged<FulfillmentMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.homeMutedFill,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SegmentChip(
              label: AppLocalizations.of(context).fulfillmentDelivery,
              icon: Icons.delivery_dining_rounded,
              selected: mode == FulfillmentMode.delivery,
              onTap: () => onChanged(FulfillmentMode.delivery),
            ),
          ),
          Expanded(
            child: _SegmentChip(
              label: AppLocalizations.of(context).fulfillmentSelfPickup,
              icon: Icons.storefront_rounded,
              selected: mode == FulfillmentMode.selfPickup,
              onTap: () => onChanged(FulfillmentMode.selfPickup),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primaryBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm - 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppColors.cardRadiusSm - 2),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : AppColors.textPrimary,
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

class _CheckoutCouponCard extends ConsumerStatefulWidget {
  const _CheckoutCouponCard({required this.controller});

  final TextEditingController controller;

  @override
  ConsumerState<_CheckoutCouponCard> createState() =>
      _CheckoutCouponCardState();
}

class _CheckoutCouponCardState extends ConsumerState<_CheckoutCouponCard> {
  bool _validating = false;

  Future<void> _applyCoupon() async {
    final String code = widget.controller.text.trim();
    if (code.isEmpty || _validating) {
      return;
    }
    setState(() => _validating = true);
    final CartState cart = ref.read(cartProvider);
    final CouponValidationResult result =
        await ref.read(couponRepositoryProvider).validate(
              code: code,
              subtotalLkr: cart.subtotal,
              storeId: cart.items.isEmpty ? '' : cart.items.first.storeId,
            );
    if (!mounted) {
      return;
    }
    setState(() => _validating = false);
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (result.isSuccess) {
      ref.read(cartProvider.notifier).setCoupon(result.coupon!);
      unawaited(AnalyticsService.logCouponApplied(result.coupon!.code));
      showMndSnackBar(
        context,
        l10n.checkoutCouponAppliedMessage(result.coupon!.code),
        variant: MndSnackBarVariant.success,
      );
    } else {
      showMndSnackBar(
        context,
        result.errorMessage ?? l10n.checkoutCouponInvalidMessage,
        variant: MndSnackBarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final CartState cart = ref.watch(cartProvider);
    final CartNotifier cartNotifier = ref.read(cartProvider.notifier);
    final CartCoupon? applied = cart.appliedCoupon;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return MndExpandableCard(
      icon: Icons.local_offer_outlined,
      title: applied != null
          ? l10n.checkoutPromoAppliedTitle
          : l10n.checkoutPromoPromptTitle,
      summary: applied?.code,
      summaryColor: AppColors.success,
      initiallyExpanded: applied != null,
      builder: (BuildContext context) {
        if (applied != null) {
          return Row(
            children: <Widget>[
              Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.success),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.checkoutPromoAppliedMessage(applied.code),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              TextButton(
                onPressed: cartNotifier.removeCoupon,
                child: Text(l10n.actionRemove),
              ),
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: widget.controller,
                textCapitalization: TextCapitalization.characters,
                enabled: !_validating,
                decoration: InputDecoration(
                  hintText: l10n.checkoutPromoHint,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            FilledButton(
              onPressed: _validating ? null : _applyCoupon,
              child: _validating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.actionApply),
            ),
          ],
        );
      },
    );
  }
}

class _CheckoutDeliveryInstructionsCard extends StatelessWidget {
  const _CheckoutDeliveryInstructionsCard({
    required this.deliveryNoteController,
    required this.specialInstructionController,
  });

  final TextEditingController deliveryNoteController;
  final TextEditingController specialInstructionController;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (BuildContext context, WidgetRef ref, _) {
        final CartNotifier cartNotifier = ref.read(cartProvider.notifier);
        final String note = deliveryNoteController.text.trim();
        final String instructions = specialInstructionController.text.trim();
        final String preview = note.isNotEmpty
            ? note
            : (instructions.isNotEmpty ? instructions : '');

        final AppLocalizations l10n = AppLocalizations.of(context);
        return MndExpandableCard(
          icon: Icons.note_alt_outlined,
          title: l10n.checkoutInstructionsTitle,
          summary: preview.isEmpty ? null : preview,
          initiallyExpanded: note.isNotEmpty || instructions.isNotEmpty,
          builder: (BuildContext context) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.checkoutDeliveryNoteLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: deliveryNoteController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: l10n.checkoutDeliveryNoteHint,
                  ),
                  onChanged: cartNotifier.setDeliveryNote,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.checkoutSpecialInstructionsLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: specialInstructionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: l10n.checkoutSpecialInstructionsHint,
                  ),
                  onChanged: cartNotifier.setSpecialInstructions,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DeliveryFulfillmentSection extends StatelessWidget {
  const _DeliveryFulfillmentSection({
    required this.hasSelectedAddress,
    required this.latitude,
    required this.longitude,
    required this.autoLocating,
    required this.line1Controller,
    required this.line2Controller,
    required this.cityController,
    required this.onManageTap,
    required this.onMapTap,
  });

  final bool hasSelectedAddress;
  final double? latitude;
  final double? longitude;
  final bool autoLocating;
  final TextEditingController line1Controller;
  final TextEditingController line2Controller;
  final TextEditingController cityController;
  final VoidCallback onManageTap;
  final VoidCallback onMapTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MndSectionHeader(
          title: l10n.checkoutDeliveryAddressHeader,
          actionLabel: l10n.actionManage,
          onActionTap: onManageTap,
        ),
        const SizedBox(height: AppSpacing.sm),
        MndPremiumCard(
          borderRadius: AppColors.cardRadiusSm,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DeliveryMapPreviewCard(
                latitude: latitude,
                longitude: longitude,
                hasSelectedAddress: hasSelectedAddress,
                loading: autoLocating,
                line1: line1Controller.text.trim(),
                line2: line2Controller.text.trim(),
                city: cityController.text.trim(),
                onTap: onMapTap,
              ),
              if (!hasSelectedAddress)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Text(
                    l10n.checkoutSaveAddressesHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small embedded map preview of the delivery pin, tap-to-open the full
/// picker to change it. Falls back to a plain tinted placeholder (no map)
/// when Google Maps isn't available on this platform/build.
class _DeliveryMapPreviewCard extends StatelessWidget {
  const _DeliveryMapPreviewCard({
    required this.latitude,
    required this.longitude,
    required this.hasSelectedAddress,
    required this.loading,
    required this.line1,
    required this.line2,
    required this.city,
    required this.onTap,
  });

  final double? latitude;
  final double? longitude;
  final bool hasSelectedAddress;
  final bool loading;
  final String line1;
  final String line2;
  final String city;
  final VoidCallback onTap;

  static const double _mapHeight = 128;
  static const LatLng _fallbackCenter = LatLng(6.9271, 79.8612); // Colombo

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool hasPin = latitude != null && longitude != null;
    final bool mapSupported =
        isDeliveryMapPickerSupported() && !MapUnavailableBanner.shouldShow;
    final LatLng center =
        hasPin ? LatLng(latitude!, longitude!) : _fallbackCenter;
    final String addressLine = <String>[
      line1,
      if (line2.isNotEmpty) line2,
      city,
    ].where((String s) => s.isNotEmpty).join(', ');

    return Semantics(
      button: true,
      label: hasSelectedAddress
          ? 'Change delivery address, currently $addressLine'
          : '${l10n.checkoutPickOnMapTitle}, ${l10n.checkoutPickOnMapSubtitle}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
            child: SizedBox(
              height: _mapHeight,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (mapSupported)
                    // Ignored so the platform map view never swallows
                    // the tap before it reaches the InkWell above —
                    // panning/zooming is disabled anyway, this is just
                    // a live preview, not a picker.
                    IgnorePointer(
                      child: GoogleMap(
                        // `initialCameraPosition` only applies when the
                        // map is first created — without a key tied to
                        // the pin, moving the pin (map picker, saved
                        // address, auto-locate) would just move the
                        // marker while the already-created map's camera
                        // stayed put, leaving the pin off-center. Keying
                        // by coordinates forces a fresh map (and a fresh
                        // initial camera) whenever the pin moves.
                        key: ValueKey<String>(
                          'checkoutMapPreview_${center.latitude}_${center.longitude}',
                        ),
                        initialCameraPosition: CameraPosition(
                          target: center,
                          zoom: 15.5,
                        ),
                        // No native Marker — the custom Drop Off pin below
                        // is drawn on top instead, so it can carry a label.
                        zoomControlsEnabled: false,
                        zoomGesturesEnabled: false,
                        scrollGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        myLocationButtonEnabled: false,
                        compassEnabled: false,
                        mapToolbarEnabled: false,
                        liteModeEnabled: true,
                      ),
                    )
                  else
                    ColoredBox(
                      color: AppColors.primaryBlue.withValues(alpha: 0.08),
                      child: const Center(
                        child: Icon(
                          Icons.map_outlined,
                          color: AppColors.primaryBlue,
                          size: 32,
                        ),
                      ),
                    ),
                  // The map never pans under this preview (gestures are
                  // disabled), so the drop-off point is always exactly at
                  // its center — a fixed custom pin here (instead of a
                  // native Marker) lets it carry a "Drop Off" label.
                  if (hasPin)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs + 2,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              l10n.checkoutDropOffLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Icon(
                            Icons.location_pin,
                            size: 34,
                            color: AppColors.primaryBlue,
                            shadows: <Shadow>[
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (loading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.32),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            l10n.checkoutLocatingLabel,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  if (!loading)
                    Positioned(
                      right: AppSpacing.xs,
                      bottom: AppSpacing.xs,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 3,
                          ),
                          child: Text(
                            l10n.checkoutTapMapToChangeHint,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickupFulfillmentSection extends ConsumerWidget {
  const _PickupFulfillmentSection({
    required this.storeId,
  });

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StorePickupInfo?> pickupAsync =
        ref.watch(storePickupInfoByStoreIdProvider(storeId));

    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MndSectionHeader(title: l10n.checkoutPickupDetailsHeader),
        const SizedBox(height: AppSpacing.sm),
        MndPremiumCard(
          borderRadius: AppColors.cardRadiusSm,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              pickupAsync.when(
                data: (StorePickupInfo? info) {
                  if (info == null) {
                    return Text(
                      l10n.checkoutPickupDetailsError,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    );
                  }
                  return _StorePickupInfoCard(info: info);
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: LinearProgressIndicator(),
                ),
                error: (Object err, _) => Text(
                  l10n.checkoutPickupDetailsError,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StorePickupInfoCard extends StatelessWidget {
  const _StorePickupInfoCard({required this.info});

  final StorePickupInfo info;

  @override
  Widget build(BuildContext context) {
    final String address = info.formattedAddress;
    final String storePhone = info.phone.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.store_mall_directory_outlined,
            color: AppColors.primaryBlue,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                info.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (address.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  address,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
              if (storePhone.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  storePhone,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill =
        selected && enabled ? AppColors.primaryBlue : AppColors.homeMutedFill;
    final Color fg =
        selected && enabled ? Colors.white : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.72,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
            child: Ink(
              height: 52,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
                border: Border.all(
                  color: selected && enabled
                      ? AppColors.primaryBlue
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget? _collapsedCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) =>
    null;

String? _deliveryFeeDetailText(
  AppLocalizations l10n,
  DeliveryFeeQuote quote,
) {
  switch (quote.detailKind) {
    case DeliveryFeeDetailKind.none:
      return null;
    case DeliveryFeeDetailKind.estimatedWithPin:
      return l10n.checkoutEstimatedFeeWithPinDetail;
    case DeliveryFeeDetailKind.estimatedNoPin:
      return l10n.checkoutEstimatedFeeDetail;
    case DeliveryFeeDetailKind.selfPickupFree:
      return l10n.checkoutSelfPickupFreeDetail;
    case DeliveryFeeDetailKind.distanceFromStore:
      return l10n.checkoutDistanceFromStoreDetail(
        quote.distanceKm!.toStringAsFixed(1),
      );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
    this.detail,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final TextStyle? base = emphasize
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyLarge;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Flexible (not the value column) so a long localized label — e.g.
        // the bank-fee percentage label in Sinhala/Tamil — wraps instead of
        // overflowing the row; the value column keeps its natural width so
        // amounts still line up flush against the card's right edge.
        Expanded(
          child: Text(label, style: base),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              value,
              textAlign: TextAlign.end,
              style: base?.copyWith(
                color: valueColor ?? (emphasize ? AppColors.primaryBlue : null),
              ),
            ),
            if (detail != null && detail!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  detail!,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CheckoutBottomBar extends StatelessWidget {
  const _CheckoutBottomBar({
    required this.totalLabel,
    required this.isPlacingOrder,
    this.blockedHint,
    this.needsSignIn = false,
    this.onSignIn,
    required this.onPlaceOrder,
  });

  final String totalLabel;
  final bool isPlacingOrder;
  final String? blockedHint;
  final bool needsSignIn;
  final VoidCallback? onSignIn;
  final VoidCallback? onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Material(
        color: AppColors.surfaceElevated,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.homeMutedFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Text(
                      l10n.cartTotalLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      totalLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (blockedHint != null &&
                    blockedHint!.isNotEmpty &&
                    !needsSignIn)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      blockedHint!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                FilledButton(
                  key: const ValueKey<String>('placeOrderButton'),
                  onPressed: needsSignIn ? onSignIn : onPlaceOrder,
                  child: isPlacingOrder
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          needsSignIn
                              ? l10n.checkoutSignInToPlaceOrder
                              : l10n.checkoutPlaceOrderButton,
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
