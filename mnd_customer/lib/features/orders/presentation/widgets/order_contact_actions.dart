import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/utils/phone_call_launcher.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/orders/data/customer_order_rider_contact_repository.dart';

/// Fetches the assigned rider's phone on tap and opens the dialer — the
/// rider's contact stays hidden until the customer actually asks for it.
class OrderCallRiderChip extends ConsumerStatefulWidget {
  const OrderCallRiderChip({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderCallRiderChip> createState() => _OrderCallRiderChipState();
}

class _OrderCallRiderChipState extends ConsumerState<OrderCallRiderChip> {
  bool _loading = false;

  Future<void> _call() async {
    if (_loading) {
      return;
    }
    setState(() => _loading = true);
    try {
      final CustomerOrderRiderContact contact = await ref.read(
        customerOrderRiderContactProvider(widget.orderId).future,
      );
      if (mounted) {
        await launchPhoneCall(context, contact.phone);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrderContactChip(
      icon: Icons.delivery_dining_rounded,
      label: 'Call rider',
      loading: _loading,
      onTap: _call,
    );
  }
}

/// Calls the vendor's store using the publicly-readable phone on their
/// vendor doc — no callable needed since store contact info isn't PII.
class OrderCallStoreChip extends ConsumerWidget {
  const OrderCallStoreChip({super.key, required this.vendorId});

  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SearchStore? vendor =
        ref.watch(vendorDocStreamProvider(vendorId)).asData?.value;
    final String phone = vendor?.phone.trim() ?? '';
    if (phone.isEmpty) {
      return const SizedBox.shrink();
    }
    return OrderContactChip(
      icon: Icons.storefront_rounded,
      label: 'Call store',
      loading: false,
      onTap: () => launchPhoneCall(context, phone),
    );
  }
}

class OrderContactChip extends StatelessWidget {
  const OrderContactChip({
    super.key,
    required this.icon,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 16, color: AppColors.primaryBlue),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
