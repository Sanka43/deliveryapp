import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';

class CustomerOrderRiderContact {
  const CustomerOrderRiderContact({required this.name, required this.phone});

  final String name;
  final String phone;
}

class CustomerOrderRiderContactException implements Exception {
  const CustomerOrderRiderContactException(this.message);
  final String message;

  @override
  String toString() => message;
}

final Provider<CustomerOrderRiderContactRepository>
    customerOrderRiderContactRepositoryProvider =
    Provider<CustomerOrderRiderContactRepository>((Ref ref) {
  return CustomerOrderRiderContactRepository(
    functions: FirebaseFunctions.instanceFor(region: 'asia-south1'),
  );
});

class CustomerOrderRiderContactRepository {
  CustomerOrderRiderContactRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<CustomerOrderRiderContact> fetch(String orderId) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('getCustomerOrderRiderContact')
          .call(<String, dynamic>{'orderId': orderId});
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
      final String phone = (data['phone'] as String?)?.trim() ?? '';
      if (phone.isEmpty) {
        throw const CustomerOrderRiderContactException(
          'Rider phone not available.',
        );
      }
      return CustomerOrderRiderContact(
        name: (data['name'] as String?)?.trim().isNotEmpty == true
            ? (data['name'] as String).trim()
            : 'Rider',
        phone: phone,
      );
    } on CustomerOrderRiderContactException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw CustomerOrderRiderContactException(
        userFacingError(e, fallback: 'Could not load rider contact.'),
      );
    } catch (_) {
      throw const CustomerOrderRiderContactException(
        'Could not load rider contact. Check your connection and try again.',
      );
    }
  }
}

/// Cached per-order rider contact lookup — only fetch once per order id.
final AutoDisposeFutureProviderFamily<CustomerOrderRiderContact, String>
    customerOrderRiderContactProvider =
    FutureProvider.autoDispose.family<CustomerOrderRiderContact, String>(
  (Ref ref, String orderId) {
    return ref
        .watch(customerOrderRiderContactRepositoryProvider)
        .fetch(orderId);
  },
);
