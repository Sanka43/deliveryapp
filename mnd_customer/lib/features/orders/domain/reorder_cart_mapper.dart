import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_detail.dart';

extension OrderLineItemReorderMapping on OrderLineItem {
  CartItem toCartItemForReorder(CustomerOrderDetail order) {
    final String sid = storeId.isNotEmpty ? storeId : order.vendorId;
    final String sname = storeName.isNotEmpty ? storeName : order.storeName;
    String pk = productKey.trim();
    if (pk.isEmpty) {
      final String raw =
          '${order.id}_${productName}_$selectedSize'.toLowerCase();
      pk = raw.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_');
      if (pk.isEmpty) {
        pk = 'reorder_item';
      }
    }
    return CartItem(
      productKey: pk,
      productName: productName,
      storeId: sid,
      storeName: sname,
      imageUrl: imageUrl,
      selectedSize: selectedSize.isNotEmpty ? selectedSize : 'Standard',
      quantity: quantity,
      basePrice: basePrice,
      sizePriceDelta: sizePriceDelta,
      extras: extras
          .map(
            (OrderLineExtra e) => CartExtra(
              name: e.name,
              priceDelta: e.priceDelta,
            ),
          )
          .toList(growable: false),
    );
  }
}
