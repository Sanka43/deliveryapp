import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_detail.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';

final AutoDisposeStreamProviderFamily<CustomerOrderDetail?, String>
    orderDetailStreamProvider =
    StreamProvider.autoDispose.family<CustomerOrderDetail?, String>(
  (Ref ref, String orderId) {
    return ref.watch(customerOrdersRepositoryProvider).watchOrderDetail(orderId);
  },
);
