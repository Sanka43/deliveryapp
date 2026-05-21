import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/features/orders/data/rider_orders_repository.dart';
import 'package:mnd_rider/features/orders/domain/rider_order_detail.dart';
import 'package:url_launcher/url_launcher.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RiderOrderDetail?> orderAsync =
        ref.watch(riderOrderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: orderAsync.when(
        data: (RiderOrderDetail? order) {
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }
          return _Body(
            order: order,
            onCall: () => _callPhone(context, order.deliveryAddress.phone),
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
        error: (Object e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.order,
    required this.onCall,
    this.onContinueTrip,
  });

  final RiderOrderDetail order;
  final VoidCallback onCall;
  final VoidCallback? onContinueTrip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: <Widget>[
        Text(
          order.storeName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          order.referenceForDisplay,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 16),
        Text('Status: ${order.status}'),
        Text('COD total: ${LkrFormat.money(order.totalLkr)}'),
        Text('Delivery fee: ${LkrFormat.money(order.deliveryFeeLkr)}'),
        const SizedBox(height: 16),
        Text(
          'Dropoff',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(order.dropoffAddressSingleLine),
        Text('Phone: ${order.deliveryAddress.phone}'),
        if (order.deliveryNote != null && order.deliveryNote!.isNotEmpty)
          Text('Note: ${order.deliveryNote}'),
        const SizedBox(height: 16),
        Text(
          'Items',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        ...order.items.map(
          (RiderOrderLineItem i) => Text('${i.quantity}× ${i.productName}'),
        ),
        const SizedBox(height: 24),
        if (order.deliveryAddress.phone.isNotEmpty)
          OutlinedButton.icon(
            onPressed: onCall,
            icon: const Icon(Icons.phone_outlined),
            label: const Text('Call customer'),
          ),
        if (onContinueTrip != null) ...<Widget>[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onContinueTrip,
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('Continue trip'),
          ),
        ],
      ],
    );
  }
}
