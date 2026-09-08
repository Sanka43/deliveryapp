import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';

class CustomerTripRiderContact {
  const CustomerTripRiderContact({required this.name, required this.phone});

  final String name;
  final String phone;
}

class CustomerTripRiderContactException implements Exception {
  const CustomerTripRiderContactException(this.message);
  final String message;

  @override
  String toString() => message;
}

final Provider<CustomerTripRiderContactRepository>
    customerTripRiderContactRepositoryProvider =
    Provider<CustomerTripRiderContactRepository>((Ref ref) {
  return CustomerTripRiderContactRepository(
    functions: FirebaseFunctions.instanceFor(region: 'asia-south1'),
  );
});

class CustomerTripRiderContactRepository {
  CustomerTripRiderContactRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<CustomerTripRiderContact> fetch(String tripId) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('getCustomerTripRiderContact')
          .call(<String, dynamic>{'tripId': tripId});
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
      final String phone = (data['phone'] as String?)?.trim() ?? '';
      if (phone.isEmpty) {
        throw const CustomerTripRiderContactException(
          'Rider phone not available.',
        );
      }
      return CustomerTripRiderContact(
        name: (data['name'] as String?)?.trim().isNotEmpty == true
            ? (data['name'] as String).trim()
            : 'Rider',
        phone: phone,
      );
    } on CustomerTripRiderContactException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw CustomerTripRiderContactException(
        userFacingError(e, fallback: 'Could not load rider contact.'),
      );
    } catch (_) {
      throw const CustomerTripRiderContactException(
        'Could not load rider contact. Check your connection and try again.',
      );
    }
  }
}

/// Cached per-trip rider contact lookup — only fetch once per trip id.
final AutoDisposeFutureProviderFamily<CustomerTripRiderContact, String>
    customerTripRiderContactProvider =
    FutureProvider.autoDispose.family<CustomerTripRiderContact, String>(
  (Ref ref, String tripId) {
    return ref
        .watch(customerTripRiderContactRepositoryProvider)
        .fetch(tripId);
  },
);
