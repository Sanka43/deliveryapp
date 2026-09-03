import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';

class VendorOrderRiderContact {
  const VendorOrderRiderContact({required this.name, required this.phone});

  final String name;
  final String phone;
}

class VendorOrderRiderContactException implements Exception {
  const VendorOrderRiderContactException(this.message);
  final String message;

  @override
  String toString() => message;
}

final Provider<VendorOrderRiderContactRepository>
    vendorOrderRiderContactRepositoryProvider =
    Provider<VendorOrderRiderContactRepository>((Ref ref) {
  return VendorOrderRiderContactRepository(
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

class VendorOrderRiderContactRepository {
  VendorOrderRiderContactRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<VendorOrderRiderContact> fetch(String orderId) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('getVendorOrderRiderContact')
          .call(<String, dynamic>{'orderId': orderId});
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
      final String phone = (data['phone'] as String?)?.trim() ?? '';
      if (phone.isEmpty) {
        throw const VendorOrderRiderContactException(
          'Rider phone not available.',
        );
      }
      return VendorOrderRiderContact(
        name: (data['name'] as String?)?.trim().isNotEmpty == true
            ? (data['name'] as String).trim()
            : 'Rider',
        phone: phone,
      );
    } on VendorOrderRiderContactException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw VendorOrderRiderContactException(
        userFacingError(e, fallback: 'Could not load rider contact.'),
      );
    } catch (_) {
      throw const VendorOrderRiderContactException(
        'Could not load rider contact. Check your connection and try again.',
      );
    }
  }
}

/// Cached per-order rider contact lookup — only fetch once per order id.
final AutoDisposeFutureProviderFamily<VendorOrderRiderContact, String>
    vendorOrderRiderContactProvider =
    FutureProvider.autoDispose.family<VendorOrderRiderContact, String>(
  (Ref ref, String orderId) {
    return ref
        .watch(vendorOrderRiderContactRepositoryProvider)
        .fetch(orderId);
  },
);
