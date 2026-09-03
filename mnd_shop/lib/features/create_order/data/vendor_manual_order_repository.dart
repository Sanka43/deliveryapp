import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';

class VendorCustomerLookupResult {
  const VendorCustomerLookupResult({
    required this.found,
    required this.isGuest,
    required this.phoneE164,
    this.customerId,
    this.displayName,
    this.suggestedLine1 = '',
    this.suggestedLine2 = '',
    this.suggestedCity = '',
    this.suggestedPhone = '',
  });

  final bool found;
  final bool isGuest;
  final String phoneE164;
  final String? customerId;
  final String? displayName;
  final String suggestedLine1;
  final String suggestedLine2;
  final String suggestedCity;
  final String suggestedPhone;
}

class VendorManualOrderResult {
  const VendorManualOrderResult({
    required this.orderId,
    required this.trackingNumber,
    required this.total,
    required this.subtotal,
    required this.deliveryFee,
    this.isGuestCustomer = false,
    this.guestSmsSent,
  });

  final String orderId;
  final String trackingNumber;
  final int total;
  final int subtotal;
  final int deliveryFee;

  /// True when the phone didn't match an MND account.
  final bool isGuestCustomer;

  /// For guest orders: whether the delivery-confirmation SMS actually sent.
  /// Null for non-guest orders (no SMS attempted).
  final bool? guestSmsSent;
}

final Provider<VendorManualOrderRepository> vendorManualOrderRepositoryProvider =
    Provider<VendorManualOrderRepository>((Ref ref) {
  return VendorManualOrderRepository(
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

class VendorManualOrderRepository {
  VendorManualOrderRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<VendorCustomerLookupResult> lookupCustomer(String phone) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('lookupVendorOrderCustomer')
          .call(<String, dynamic>{'phone': phone.trim()});
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
      final Map<String, dynamic>? addr = data['suggestedAddress'] is Map
          ? Map<String, dynamic>.from(
              data['suggestedAddress'] as Map<dynamic, dynamic>,
            )
          : null;
      return VendorCustomerLookupResult(
        found: data['found'] == true,
        isGuest: data['isGuest'] == true,
        phoneE164: (data['phoneE164'] as String?)?.trim() ?? phone.trim(),
        customerId: (data['customerId'] as String?)?.trim(),
        displayName: (data['displayName'] as String?)?.trim(),
        suggestedLine1: (addr?['line1'] as String?)?.trim() ?? '',
        suggestedLine2: (addr?['line2'] as String?)?.trim() ?? '',
        suggestedCity: (addr?['city'] as String?)?.trim() ?? '',
        suggestedPhone: (addr?['phone'] as String?)?.trim() ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      throw VendorManualOrderException(_mapError(e));
    } catch (_) {
      throw const VendorManualOrderException(
        'Could not look up customer. Check your connection and try again.',
      );
    }
  }

  Future<VendorManualOrderResult> placeOrder({
    required String customerPhone,
    required String customerName,
    required int packagePriceLkr,
    required String packageDescription,
    required String line1,
    required String line2,
    required String city,
    required String addressPhone,
    double? dropoffLatitude,
    double? dropoffLongitude,
    bool productsPaid = false,
    String deliveryNote = '',
    String specialInstructions = '',
  }) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('placeVendorManualOrder')
          .call(<String, dynamic>{
        'customerPhone': customerPhone.trim(),
        'customerName': customerName.trim(),
        'packagePriceLkr': packagePriceLkr,
        if (packageDescription.trim().isNotEmpty)
          'packageDescription': packageDescription.trim(),
        'deliveryAddress': <String, dynamic>{
          'line1': line1.trim(),
          'line2': line2.trim(),
          'city': city.trim(),
          'phone': addressPhone.trim(),
        },
        'productsPaid': productsPaid,
        'dropoffLatitude': ?dropoffLatitude,
        'dropoffLongitude': ?dropoffLongitude,
        if (deliveryNote.trim().isNotEmpty)
          'deliveryNote': deliveryNote.trim(),
        if (specialInstructions.trim().isNotEmpty)
          'specialInstructions': specialInstructions.trim(),
      });
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
      final String orderId = (data['orderId'] as String?)?.trim() ?? '';
      if (orderId.isEmpty) {
        throw const VendorManualOrderException('Order created but missing id.');
      }
      return VendorManualOrderResult(
        orderId: orderId,
        trackingNumber: (data['trackingNumber'] as String?)?.trim() ?? '',
        total: _readInt(data['total']),
        subtotal: _readInt(data['subtotal']),
        deliveryFee: _readInt(data['deliveryFee']),
        isGuestCustomer: data['isGuestCustomer'] == true,
        guestSmsSent: data['guestSmsSent'] is bool
            ? data['guestSmsSent'] as bool
            : null,
      );
    } on VendorManualOrderException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw VendorManualOrderException(_mapError(e));
    } catch (_) {
      throw const VendorManualOrderException(
        'Could not create the order. Check your connection and try again.',
      );
    }
  }

  static int _readInt(Object? v) {
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.round();
    }
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _mapError(FirebaseFunctionsException e) {
    final String? message = e.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    switch (e.code) {
      case 'unauthenticated':
        return 'Sign in again to create an order.';
      case 'permission-denied':
        return 'Only registered vendors can create orders.';
      case 'failed-precondition':
        return 'Shop is not accepting orders right now.';
      case 'not-found':
        return 'A product or store was not found.';
      case 'invalid-argument':
        return 'Check customer, items, and delivery details.';
      default:
        return 'Something went wrong. Try again.';
    }
  }
}

class VendorManualOrderException implements Exception {
  const VendorManualOrderException(this.message);
  final String message;

  @override
  String toString() => message;
}
