import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_detail.dart';
import 'package:mnd_delivery_app/features/orders/domain/reorder_cart_mapper.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/order_detail_provider.dart';

Future<void> reorderFromOrderId(
  BuildContext context,
  WidgetRef ref,
  String orderId,
) async {
  final CustomerOrderDetail? order = await ref
      .read(orderDetailStreamProvider(orderId).future)
      .catchError((_) => null);

  if (!context.mounted) {
    return;
  }

  if (order == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not load order for reorder.')),
    );
    return;
  }

  await handleReorder(context, ref, order);
}

Future<void> handleReorder(
  BuildContext context,
  WidgetRef ref,
  CustomerOrderDetail order,
) async {
  if (order.items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No items to add from this order.')),
    );
    return;
  }
  if (order.vendorId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cannot reorder — missing store information.')),
    );
    return;
  }

  final List<CartItem> cartItems = order.items
      .map((OrderLineItem line) => line.toCartItemForReorder(order))
      .toList(growable: false);

  final CartNotifier notifier = ref.read(cartProvider.notifier);
  final CartState cart = ref.read(cartProvider);

  final bool sameOrEmpty =
      cart.isEmpty || cart.items.first.storeId == order.vendorId;

  if (sameOrEmpty) {
    final bool ok = notifier.mergeItemsFromSameStore(order.vendorId, cartItems);
    if (!context.mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update cart.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cartItems.length == 1
              ? 'Added item to your cart.'
              : 'Added ${cartItems.length} items to your cart.',
        ),
      ),
    );
    return;
  }

  final bool? replace = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Different store'),
      content: const Text(
        'Your cart has items from another store. Clear the cart and add these items instead?',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Clear & reorder'),
        ),
      ],
    ),
  );

  if (replace != true || !context.mounted) {
    return;
  }

  notifier.replaceCartContents(
    cartItems,
    deliveryNote: order.deliveryNote,
    specialInstructions: order.specialInstructions,
    dropoffLatitude: order.dropoffLatitude,
    dropoffLongitude: order.dropoffLongitude,
  );

  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        cartItems.length == 1
            ? 'Cart updated with your previous item.'
            : 'Cart updated with ${cartItems.length} items from this order.',
      ),
    ),
  );
}
