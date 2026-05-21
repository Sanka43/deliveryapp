import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/delivery_fee_quote_provider.dart';
import 'package:mnd_delivery_app/features/orders/data/order_placement_repository.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/order_placement_repository_provider.dart';
import 'package:mnd_delivery_app/features/customer/data/saved_address.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/saved_addresses_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/address_form_dialog.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_pick_result.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_picker_page.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';

enum CheckoutPaymentMethod {
  cashOnDelivery,
  card,
  wallet,
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
  CheckoutPaymentMethod _payment = CheckoutPaymentMethod.cashOnDelivery;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedSavedId;
  bool _placingOrder = false;

  @override
  void dispose() {
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// When non-null, place order must stay disabled (sign-in only).
  /// Firestore rules enforce [validOrderCreate] (including customerId == auth uid).
  static String? _placeOrderBlockReason(AsyncValue<User?> authAsync) {
    if (authAsync.isLoading) {
      return 'Checking sign-in…';
    }
    if (authAsync.hasError) {
      return 'Could not load sign-in state.';
    }
    final User? user = authAsync.value;
    if (user == null) {
      return 'Sign in to place an order.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<User?> authAsync = ref.watch(authStateUserProvider);
    final String? placeOrderBlock = _placeOrderBlockReason(authAsync);

    final CartState cart = ref.watch(cartProvider);
    final DeliveryFeeQuote deliveryQuote = ref.watch(deliveryFeeQuoteProvider);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Cart empty — add items before checkout.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.customerCart),
                  child: const Text('Go to cart'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final int subtotal = cart.subtotal;
    final int discount = cart.discount;
    final int deliveryFee = deliveryQuote.feeLkr;
    final int total = subtotal - discount + deliveryFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (placeOrderBlock != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: placeOrderBlock == 'Sign in to place an order.'
                            ? const SignInRequiredBanner()
                            : DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Icon(
                                        Icons.info_outline,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer,
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
                                                    .onErrorContainer,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Delivery address',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.customerSavedAddresses),
                          child: const Text('Manage'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Consumer(
                      builder: (BuildContext context, WidgetRef ref, _) {
                        final AsyncValue<List<SavedAddress>> async =
                            ref.watch(savedAddressesStreamProvider);
                        return async.when(
                          data: (List<SavedAddress> list) {
                            if (list.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Use saved',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Wrap(
                                    spacing: AppSpacing.xs,
                                    runSpacing: AppSpacing.xs,
                                    children: list.map((SavedAddress a) {
                                      final bool selected = _selectedSavedId == a.id;
                                      return FilterChip(
                                        label: Text(
                                          '${a.label}${a.isDefault ? ' ★' : ''}',
                                        ),
                                        selected: selected,
                                        onSelected: (_) {
                                          ref.read(cartProvider.notifier).clearDropoffLocation();
                                          setState(() {
                                            _selectedSavedId = a.id;
                                            _line1Controller.text = a.line1;
                                            _line2Controller.text = a.line2;
                                            _cityController.text = a.city;
                                            _phoneController.text = a.phone;
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.sm),
                            child: LinearProgressIndicator(),
                          ),
                          error: (Object err, _) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Text(
                              'Could not load saved addresses.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: _saveCurrentAsNewSavedAddress,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Save filled address'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton.icon(
                      onPressed: _openDeliveryMapPicker,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Pick on map'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _line1Controller,
                      decoration: const InputDecoration(
                        labelText: 'Address line 1',
                        hintText: 'Street, house / flat no.',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 200,
                      buildCounter: _collapsedCounter,
                      validator: (String? v) {
                        final String t = v?.trim() ?? '';
                        if (t.isEmpty) {
                          return 'Required';
                        }
                        if (t.length > 200) {
                          return 'Max 200 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _line2Controller,
                      decoration: const InputDecoration(
                        labelText: 'Address line 2 (optional)',
                        hintText: 'Landmark, building',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 200,
                      buildCounter: _collapsedCounter,
                      validator: (String? v) {
                        if ((v?.trim().length ?? 0) > 200) {
                          return 'Max 200 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        hintText: 'e.g. Colombo',
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 80,
                      buildCounter: _collapsedCounter,
                      validator: (String? v) {
                        final String t = v?.trim() ?? '';
                        if (t.isEmpty) {
                          return 'Required';
                        }
                        if (t.length > 80) {
                          return 'Max 80 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Contact phone',
                        hintText: '07x xxx xxxx',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 20,
                      buildCounter: _collapsedCounter,
                      validator: (String? v) {
                        final String t = v?.trim() ?? '';
                        if (t.length < 8) {
                          return 'Enter a valid phone (8–20 digits)';
                        }
                        if (t.length > 20) {
                          return 'Max 20 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Payment method',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PaymentOptionTile(
                      title: 'Cash on delivery',
                      subtitle: 'Pay when you receive',
                      selected: _payment == CheckoutPaymentMethod.cashOnDelivery,
                      enabled: true,
                      onTap: () => setState(() => _payment = CheckoutPaymentMethod.cashOnDelivery),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _PaymentOptionTile(
                      title: 'Card',
                      subtitle: 'Coming soon',
                      selected: _payment == CheckoutPaymentMethod.card,
                      enabled: false,
                      onTap: () => setState(() => _payment = CheckoutPaymentMethod.card),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _PaymentOptionTile(
                      title: 'Wallet',
                      subtitle: 'Coming soon',
                      selected: _payment == CheckoutPaymentMethod.wallet,
                      enabled: false,
                      onTap: () => setState(() => _payment = CheckoutPaymentMethod.wallet),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Order summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SummaryRow(label: 'Items', value: '${cart.itemCount}'),
                    const SizedBox(height: AppSpacing.xs),
                    _SummaryRow(label: 'Subtotal', value: _formatLkr(subtotal)),
                    if (discount > 0) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      _SummaryRow(
                        label: 'Discount',
                        value: '- ${_formatLkr(discount)}',
                        valueColor: Colors.green.shade700,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    _SummaryRow(
                      label: 'Delivery',
                      value: _formatLkr(deliveryFee),
                      detail: deliveryQuote.detail,
                    ),
                    const Divider(height: AppSpacing.lg),
                    _SummaryRow(
                      label: 'Total',
                      value: _formatLkr(total),
                      emphasize: true,
                    ),
                    if (cart.deliveryNote.isNotEmpty || cart.specialInstructions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Notes from cart',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (cart.deliveryNote.isNotEmpty)
                        Text(
                          'Delivery: ${cart.deliveryNote}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (cart.specialInstructions.isNotEmpty)
                        Text(
                          'Instructions: ${cart.specialInstructions}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
          _CheckoutBottomBar(
            totalLabel: _formatLkr(total),
            isPlacingOrder: _placingOrder,
            blockedHint: placeOrderBlock,
            needsSignIn: placeOrderBlock == 'Sign in to place an order.',
            onSignIn: placeOrderBlock == 'Sign in to place an order.'
                ? () => navigateToSignInForCheckout(ref, context)
                : null,
            onPlaceOrder: _placingOrder || placeOrderBlock != null
                ? null
                : () => _onPlaceOrder(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openDeliveryMapPicker() async {
    if (!isDeliveryMapPickerSupported()) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Map picker is available on Android and iOS only.')),
      );
      return;
    }
    final DeliveryMapPickResult? pick = await DeliveryMapPickerPage.pick(context);
    if (pick == null || !mounted) {
      return;
    }
    ref.read(cartProvider.notifier).setDropoffLocation(pick.latitude, pick.longitude);
    setState(() {
      _selectedSavedId = null;
      _line1Controller.text = pick.line1;
      _line2Controller.text = pick.line2;
      _cityController.text = pick.city;
    });
  }

  Future<void> _saveCurrentAsNewSavedAddress() async {
    final String line1 = _line1Controller.text.trim();
    final String city = _cityController.text.trim();
    final String phone = _phoneController.text.trim();
    if (line1.isEmpty || city.isEmpty || phone.length < 8) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill address line 1, city, and phone (8+ digits) before saving.'),
        ),
      );
      return;
    }

    final SavedAddress? result = await showDialog<SavedAddress>(
      context: context,
      builder: (BuildContext ctx) => AddressFormDialog(
        title: 'Save address',
        onMapPickApplied: (DeliveryMapPickResult pick) {
          ref.read(cartProvider.notifier).setDropoffLocation(pick.latitude, pick.longitude);
        },
        initial: SavedAddress(
          id: '',
          label: '',
          line1: _line1Controller.text.trim(),
          line2: _line2Controller.text.trim(),
          city: _cityController.text.trim(),
          phone: _phoneController.text.trim(),
          isDefault: false,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final String? err = await ref.read(savedAddressesActionsProvider).addAddress(
          label: result.label,
          line1: result.line1,
          line2: result.line2,
          city: result.city,
          phone: result.phone,
          setAsDefault: result.isDefault,
        );

    if (!mounted) {
      return;
    }

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address saved.')),
      );
    }
  }

  Future<void> _onPlaceOrder(BuildContext context) async {
    final String? block = _placeOrderBlockReason(ref.read(authStateUserProvider));
    if (block != null) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(block)));
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_payment != CheckoutPaymentMethod.cashOnDelivery) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('For now only Cash on delivery is available.')),
      );
      return;
    }

    final CartState previewCart = ref.read(cartProvider);
    final DeliveryFeeQuote previewQuote = ref.read(deliveryFeeQuoteProvider);
    final int previewTotal =
        previewCart.subtotal - previewCart.discount + previewQuote.feeLkr;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Place order?'),
        content: Text('Pay ${_formatLkr(previewTotal)} on delivery.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm != true || !context.mounted) {
      return;
    }

    final CartState cart = ref.read(cartProvider);
    final DeliveryFeeQuote quote = ref.read(deliveryFeeQuoteProvider);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty. Add items and try again.')),
      );
      return;
    }
    final int subtotal = cart.subtotal;
    final int discount = cart.discount;
    final int deliveryFee = quote.feeLkr;
    final int total = subtotal - discount + deliveryFee;
    if (total < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid order total. Please refresh the cart.')),
      );
      return;
    }

    setState(() => _placingOrder = true);
    try {
      final OrderPlacementRepository repo = ref.read(orderPlacementRepositoryProvider);
      final OrderPlacementResult result = await repo.placeCashOnDeliveryOrder(
        cart: cart,
        subtotal: subtotal,
        discount: discount,
        deliveryFee: deliveryFee,
        total: total,
        addressLine1: _line1Controller.text.trim(),
        addressLine2: _line2Controller.text.trim(),
        city: _cityController.text.trim(),
        phone: _phoneController.text.trim(),
        couponCode: cart.appliedCoupon?.code,
      );

      if (!context.mounted) {
        return;
      }

      if (!result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage ?? 'Order failed.')),
        );
        return;
      }

      ref.read(cartProvider.notifier).clear();
      final String? tn = result.trackingNumber?.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tn != null && tn.isNotEmpty
                ? 'Order placed — tracking $tn. Thank you!'
                : 'Order placed — thank you!',
          ),
        ),
      );
      context.go(AppRoutes.customer);
    } finally {
      if (mounted) {
        setState(() => _placingOrder = false);
      }
    }
  }
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primaryBlue.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? AppColors.primaryBlue : Colors.black45,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
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

Widget? _collapsedCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) =>
    null;

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
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyLarge;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: base),
        const Spacer(),
        Flexible(
          child: Column(
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
                          color: Colors.black54,
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
    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.titleMedium,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              FilledButton(
                onPressed: needsSignIn ? onSignIn : onPlaceOrder,
                child: isPlacingOrder
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(needsSignIn ? 'Sign in to place order' : 'Place order'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatLkr(int amount) => 'LKR $amount';
