import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/core/widgets/rider_error_state.dart';
import 'package:mnd_rider/core/widgets/rider_primary_cta.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:mnd_rider/features/orders/presentation/providers/vendor_phone_provider.dart';
import 'package:url_launcher/url_launcher.dart';

String _humanOrderStatus(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'ready_for_pickup':
    case 'ready':
      return 'Ready for pickup';
    case 'picked_up':
      return 'Picked up';
    case 'on_the_way':
    case 'out_for_delivery':
      return 'On the way';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
      return 'Cancelled';
    case 'accepted':
      return 'Accepted';
    default:
      return raw.replaceAll('_', ' ');
  }
}

class RiderOrderDetailPage extends ConsumerWidget {
  const RiderOrderDetailPage({super.key, required this.orderId});

  final String orderId;

  Future<void> _callPhone(BuildContext context, String phone) async {
    final String digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) {
      return;
    }
    final Uri uri = Uri(scheme: 'tel', path: digits);
    if (!await launchUrl(uri) && context.mounted) {
      showRiderSnackBar(context, 'Could not open phone dialer');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RiderOrderDetail?> orderAsync =
        ref.watch(riderOrderDetailProvider(orderId));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Order details')),
      body: orderAsync.when(
        data: (RiderOrderDetail? order) {
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }
          final String? shopPhone =
              ref.watch(vendorPhoneProvider(order.vendorId)).valueOrNull;
          return _Body(
            order: order,
            shopPhone: shopPhone,
            onCallCustomer: () =>
                _callPhone(context, order.deliveryAddress.phone),
            onCallShop: shopPhone == null || shopPhone.isEmpty
                ? null
                : () => _callPhone(context, shopPhone),
            onContinueTrip: order.isActiveDelivery
                ? () {
                    context.push(
                      '${RoutePaths.trip}/${order.id}',
                      extra: order,
                    );
                  }
                : null,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: RiderErrorState(
            message: userFacingError(e),
            onRetry: () => ref.invalidate(riderOrderDetailProvider(orderId)),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.order,
    required this.onCallCustomer,
    this.onCallShop,
    this.shopPhone,
    this.onContinueTrip,
  });

  final RiderOrderDetail order;
  final VoidCallback onCallCustomer;
  final VoidCallback? onCallShop;
  final String? shopPhone;
  final VoidCallback? onContinueTrip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color statusColor = switch (order.status) {
      'delivered' => AppColors.onlineGreen,
      'cancelled' => cs.error,
      _ => AppColors.primaryBlue,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: <Widget>[
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.onlineGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: AppColors.onlineGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          order.storeName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.referenceForDisplay,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontFamily: 'monospace',
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      _humanOrderStatus(order.status),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (order.isPrepaidOnline) ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.onlineGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                    border: Border.all(
                      color: AppColors.onlineGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.onlineGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Prepaid online — no cash to collect',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.onlineGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _MoneyRow(label: 'Delivery fee', amount: order.deliveryFeeLkr),
              ] else ...<Widget>[
                if (!order.productsPaid)
                  _MoneyRow(label: 'Subtotal', amount: order.subtotalLkr),
                if (order.discountLkr > 0)
                  _MoneyRow(
                    label: 'Discount',
                    amount: -order.discountLkr,
                  ),
                _MoneyRow(label: 'Delivery fee', amount: order.deliveryFeeLkr),
                if (order.serviceChargeLkr > 0)
                  _MoneyRow(
                    label: 'Service charge',
                    amount: order.serviceChargeLkr,
                  ),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'COD to collect',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      LkrFormat.money(order.collectAmountLkr()),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if ((order.pickupAddress ?? '').isNotEmpty) ...<Widget>[
                _AddressRow(
                  icon: Icons.store_mall_directory_outlined,
                  label: 'Pickup',
                  text: order.pickupAddress!,
                ),
                const SizedBox(height: 12),
              ],
              _AddressRow(
                icon: Icons.location_on_outlined,
                label: 'Dropoff',
                text: order.dropoffAddressSingleLine,
              ),
              if (order.deliveryAddress.phone.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _AddressRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  text: order.deliveryAddress.phone,
                ),
              ],
              if ((order.deliveryNote ?? '').isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _AddressRow(
                  icon: Icons.sticky_note_2_outlined,
                  label: 'Note',
                  text: order.deliveryNote!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Items',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 10),
              ...order.items.map(
                (RiderOrderLineItem i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      Text(
                        '${i.quantity}×',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          i.productName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (onCallShop != null) ...<Widget>[
          SizedBox(
            height: AppSpacing.ctaHeight,
            child: OutlinedButton.icon(
              onPressed: onCallShop,
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Call shop'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (order.deliveryAddress.phone.isNotEmpty)
          SizedBox(
            height: AppSpacing.ctaHeight,
            child: OutlinedButton.icon(
              onPressed: onCallCustomer,
              icon: const Icon(Icons.phone_outlined),
              label: const Text('Call customer'),
            ),
          ),
        if (onContinueTrip != null) ...<Widget>[
          const SizedBox(height: 10),
          RiderPrimaryCta(
            label: 'Continue trip',
            icon: Icons.navigation_rounded,
            color: AppColors.primaryBlue,
            height: AppSpacing.ctaHeight,
            onPressed: onContinueTrip,
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            amount < 0
                ? '- ${LkrFormat.money(-amount)}'
                : LkrFormat.money(amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: AppColors.offlineGrey),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
