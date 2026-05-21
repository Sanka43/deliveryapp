import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/features/orders/data/order_placement_repository.dart';

final Provider<OrderPlacementRepository> orderPlacementRepositoryProvider =
    Provider<OrderPlacementRepository>((Ref ref) {
  return OrderPlacementRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});
