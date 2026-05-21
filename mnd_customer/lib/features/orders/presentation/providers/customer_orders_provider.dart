import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/features/orders/data/customer_orders_repository.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';

final Provider<CustomerOrdersRepository> customerOrdersRepositoryProvider =
    Provider<CustomerOrdersRepository>((Ref ref) {
  return CustomerOrdersRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Real-time list of the current customer’s orders (newest first).
final StreamProvider<List<CustomerOrderSummary>> customerOrdersStreamProvider =
    StreamProvider<List<CustomerOrderSummary>>((Ref ref) {
  return ref.watch(customerOrdersRepositoryProvider).watchMyOrders();
});
