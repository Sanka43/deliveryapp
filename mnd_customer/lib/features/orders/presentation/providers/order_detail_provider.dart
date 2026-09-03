import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_detail.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';

/// Watches [authStateUserProvider] so the stream rebinds after sign-in / sign-out.
final AutoDisposeStreamProviderFamily<CustomerOrderDetail?, String>
    orderDetailStreamProvider =
    StreamProvider.autoDispose.family<CustomerOrderDetail?, String>(
  (Ref ref, String orderId) {
    final User? user = resolveAuthUser(ref);
    if (user == null) {
      return Stream<CustomerOrderDetail?>.value(null);
    }
    return ref.watch(customerOrdersRepositoryProvider).watchOrderDetail(
          orderId: orderId,
          customerUid: user.uid,
        );
  },
);
