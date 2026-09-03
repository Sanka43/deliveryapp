import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/features/cart/domain/platform_fee_config.dart';

/// Live admin-tunable delivery-fee / service-charge config from
/// `platform_config/fees`. Consumers should read
/// `.valueOrNull ?? const PlatformFeeConfig.defaults()` so checkout math
/// never breaks while loading, offline, or on a read error.
final StreamProvider<PlatformFeeConfig> platformFeeConfigProvider =
    StreamProvider<PlatformFeeConfig>((Ref ref) {
  final FirebaseFirestore db = ref.watch(firestoreProvider);
  return db
      .collection('platform_config')
      .doc('fees')
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> snap) =>
          PlatformFeeConfig.fromFirestore(snap.data()));
});
