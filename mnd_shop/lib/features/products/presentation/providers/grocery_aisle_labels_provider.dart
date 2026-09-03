import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/products/domain/vendor_grocery_catalog.dart';

/// Active grocery aisle labels from Firestore, ordered. Empty snapshots keep
/// the caller on [kGroceryAisleLabels] via [groceryAisleLabelsOrFallback].
final StreamProvider<List<String>> groceryAisleLabelsProvider =
    StreamProvider<List<String>>((Ref ref) {
  final FirebaseFirestore fs = ref.watch(firestoreProvider);
  return fs
      .collection(FirebaseCollections.groceryAisles)
      .orderBy('order')
      .snapshots()
      .map(_parseActiveAisleLabels);
});

List<String> _parseActiveAisleLabels(
  QuerySnapshot<Map<String, dynamic>> snap,
) {
  final List<String> out = <String>[];
  for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
    final Map<String, dynamic> m = doc.data();
    final dynamic act = m['active'];
    if (act is bool && act == false) {
      continue;
    }
    final String? label = (m['label'] as String?)?.trim();
    if (label != null && label.isNotEmpty) {
      out.add(label);
    }
  }
  return out;
}

/// Sync list for forms: stream data when non-empty, else hardcoded fallback.
List<String> groceryAisleLabelsOrFallback(AsyncValue<List<String>> async) {
  return async.maybeWhen(
    data: (List<String> labels) =>
        labels.isEmpty ? kGroceryAisleLabels : labels,
    orElse: () => kGroceryAisleLabels,
  );
}
