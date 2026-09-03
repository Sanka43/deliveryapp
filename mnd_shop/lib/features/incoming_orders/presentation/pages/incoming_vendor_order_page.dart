import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/utils/phone_call_launcher.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/orders/data/vendor_order_rider_contact_repository.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_order_items_list.dart';

/// Full-screen order details. [readOnly] hides accept/reject (e.g. kitchen / ready pipeline).
class IncomingVendorOrderPage extends ConsumerWidget {
  const IncomingVendorOrderPage({
    super.key,
    required this.order,
    this.readOnly = false,
  });

  final VendorPendingOrder order;

  /// When true, body is view-only; close/dismiss does not return accept/reject flags.
  final bool readOnly;

  static String _money(double v) => 'Rs. ${v.toStringAsFixed(2)}';

  static String _statusBannerLabel(String statusKey) {
    switch (statusKey.toLowerCase()) {
      case 'placed':
        return 'Incoming order';
      case 'confirmed':
      case 'preparing':
        return 'In kitchen';
      case 'ready':
        return 'Ready for pickup';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Order';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Dismiss',
          onPressed: () =>
              readOnly ? Navigator.of(context).pop<void>() : Navigator.of(context).pop<bool?>(null),
        ),
        title: const Text('Order details'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, readOnly ? 24 : 100),
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.primaryBlue.withValues(alpha: 0.95),
                  AppColors.primaryBlue.withValues(alpha: 0.78),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          readOnly ? _statusBannerLabel(order.statusKey) : 'Incoming Order',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          order.referenceForDisplay,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (order.placedAtLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            order.placedAtLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (order.customerPhone.isNotEmpty ||
              order.customerName.isNotEmpty ||
              order.isGuestCustomer)
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (order.customerName.isNotEmpty || order.isGuestCustomer) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            order.customerName.isNotEmpty
                                ? order.customerName
                                : 'Customer',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (order.isGuestCustomer) const _GuestOrderBadge(),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (order.customerPhone.isNotEmpty)
                    _CallContactRow(
                      label: 'Customer',
                      phone: order.customerPhone,
                      onCall: () => launchPhoneCall(context, order.customerPhone),
                    ),
                  if (order.isGuestCustomer) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      'Guest order — the customer got a verification code by SMS. '
                      'The rider will ask for it to confirm delivery.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 14),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      order.isSelfPickup
                          ? Icons.storefront_rounded
                          : Icons.delivery_dining_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.isSelfPickup ? 'Self pickup' : 'Delivery',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (order.deliveryAddressLabel.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.place_outlined, size: 20, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.deliveryAddressLabel,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (order.hasAssignedRider) ...<Widget>[
            const SizedBox(height: 14),
            _RiderContactCard(orderId: order.id),
          ],
          const SizedBox(height: 14),
          _TotalBanner(amount: _money(order.total)),
          const SizedBox(height: 14),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Items',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                VendorOrderItemsList(
                  items: order.items,
                  primaryText: cs.onSurface,
                  mutedText: cs.onSurfaceVariant,
                  emphasizeVariants: true,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: readOnly
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop<bool>(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error.withValues(alpha: 0.85)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop<bool>(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.openGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Consistent bordered/shadowed card shell shared by every order-detail section.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 36,
            spreadRadius: -8,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Small pill flagging a guest (unregistered-phone) order — SMS-verified at delivery.
class _GuestOrderBadge extends StatelessWidget {
  const _GuestOrderBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.pendingAmber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.pendingAmber.withValues(alpha: 0.4)),
      ),
      child: Text(
        'GUEST',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.pendingAmber,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              fontSize: 10,
            ),
      ),
    );
  }
}

/// Tappable phone row — name/label + number + call icon.
class _CallContactRow extends StatelessWidget {
  const _CallContactRow({
    required this.label,
    required this.phone,
    required this.onCall,
    this.subtitle,
  });

  final String label;
  final String phone;
  final VoidCallback onCall;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCall,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.openGreen.withValues(alpha: 0.14),
                child: Icon(
                  Icons.call_rounded,
                  size: 18,
                  color: AppColors.openGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      subtitle ?? label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      phone,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fetches + shows the assigned rider's name/phone once the order has a rider.
class _RiderContactCard extends ConsumerWidget {
  const _RiderContactCard({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<VendorOrderRiderContact> contact = ref.watch(
      vendorOrderRiderContactProvider(orderId),
    );

    return contact.when(
      loading: () => _SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: const Row(
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading rider contact…'),
          ],
        ),
      ),
      // Rider contact is a bonus, not core order info — never show a broken
      // page over it, just quietly omit the card if it can't be fetched.
      error: (Object _, StackTrace _) => const SizedBox.shrink(),
      data: (VendorOrderRiderContact riderContact) => _SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: _CallContactRow(
          label: 'Rider',
          subtitle: 'Rider · ${riderContact.name}',
          phone: riderContact.phone,
          onCall: () => launchPhoneCall(context, riderContact.phone),
        ),
      ),
    );
  }
}

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(Icons.payments_outlined, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Text(
              'Order total',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              amount,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
