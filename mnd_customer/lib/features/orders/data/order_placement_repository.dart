import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';

class OrderPlacementResult {
  const OrderPlacementResult._({this.orderId, this.trackingNumber, this.errorMessage});

  factory OrderPlacementResult.success(String id, {String? trackingNumber}) {
    return OrderPlacementResult._(orderId: id, trackingNumber: trackingNumber, errorMessage: null);
  }

  factory OrderPlacementResult.failure(String message) {
    return OrderPlacementResult._(orderId: null, trackingNumber: null, errorMessage: message);
  }

  final String? orderId;
  final String? trackingNumber;
  final String? errorMessage;

  bool get isSuccess => orderId != null;
}

class OrderPayHereCheckout {
  const OrderPayHereCheckout({
    required this.orderId,
    required this.trackingNumber,
    required this.checkoutPageUrl,
    required this.sandbox,
    required this.fields,
  });

  final String orderId;
  final String trackingNumber;
  final String checkoutPageUrl;

  /// Whether to hit PayHere's sandbox gateway (from `PAYHERE_MODE`).
  final bool sandbox;

  /// Raw PayHere checkout parameters (merchant_id, order_id, amount, etc.),
  /// passed straight into the native SDK's payment object.
  final Map<String, dynamic> fields;

  factory OrderPayHereCheckout.fromCallable(Map<String, dynamic> data) {
    final Map<dynamic, dynamic>? rawFields = data['fields'] as Map<dynamic, dynamic>?;
    return OrderPayHereCheckout(
      orderId: (data['orderId'] as String?)?.trim() ?? '',
      trackingNumber: (data['trackingNumber'] as String?)?.trim() ?? '',
      checkoutPageUrl: (data['checkoutPageUrl'] as String?)?.trim() ?? '',
      sandbox: data['sandbox'] as bool? ?? true,
      fields: rawFields == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(rawFields),
    );
  }
}

/// Places a COD order via [placeCashOnDeliveryOrder] Cloud Function so prices,
/// delivery fee, and coupons are recomputed server-side.
class OrderPlacementRepository {
  OrderPlacementRepository({
    required FirebaseAuth auth,
    FirebaseFunctions? functions,
  })  : _auth = auth,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Map<String, dynamic>? _buildOrderPayload({
    required CartState cart,
    required String addressLine1,
    required String addressLine2,
    required String city,
    required String phone,
    String? couponCode,
  }) {
    final String vendorId = cart.items.first.storeId;
    if (vendorId.isEmpty) {
      return null;
    }
    return <String, dynamic>{
      'vendorId': vendorId,
      'items': cart.items
          .map(
            (CartItem item) => <String, dynamic>{
              'productKey': item.productKey,
              'quantity': item.quantity,
              'selectedSize': item.selectedSize,
              'extras': item.extras
                  .map(
                    (CartExtra e) => <String, dynamic>{
                      'name': e.name,
                      'priceDelta': e.priceDelta,
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
      'deliveryAddress': <String, dynamic>{
        'line1': addressLine1.trim(),
        'line2': addressLine2.trim(),
        'city': city.trim(),
        'phone': phone.trim(),
      },
      'deliveryNote': cart.deliveryNote.trim(),
      'specialInstructions': cart.specialInstructions.trim(),
      'fulfillmentMode': cart.fulfillmentMode.firestoreValue,
      if (couponCode != null && couponCode.trim().isNotEmpty)
        'couponCode': couponCode.trim(),
      if (!cart.isSelfPickup &&
          cart.dropoffLatitude != null &&
          cart.dropoffLongitude != null) ...<String, dynamic>{
        'dropoffLatitude': cart.dropoffLatitude,
        'dropoffLongitude': cart.dropoffLongitude,
      },
    };
  }

  Future<OrderPlacementResult> placeCashOnDeliveryOrder({
    required CartState cart,
    required String addressLine1,
    required String addressLine2,
    required String city,
    required String phone,
    String? couponCode,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return OrderPlacementResult.failure('Sign in to place an order.');
    }
    if (cart.isEmpty) {
      return OrderPlacementResult.failure('Your cart is empty.');
    }

    final Map<String, dynamic>? payload = _buildOrderPayload(
      cart: cart,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      phone: phone,
      couponCode: couponCode,
    );
    if (payload == null) {
      return OrderPlacementResult.failure('Missing store for this cart.');
    }

    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('placeCashOnDeliveryOrder')
          .call(payload);

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
      final String orderId = (data['orderId'] as String?)?.trim() ?? '';
      final String? tracking =
          (data['trackingNumber'] as String?)?.trim();
      if (orderId.isEmpty) {
        return OrderPlacementResult.failure('Order was not created.');
      }
      return OrderPlacementResult.success(
        orderId,
        trackingNumber: (tracking == null || tracking.isEmpty) ? null : tracking,
      );
    } catch (e) {
      return OrderPlacementResult.failure(
        userFacingError(e, fallback: 'Could not place order.'),
      );
    }
  }

  /// Creates a `draft_payment` order and returns PayHere checkout fields.
  /// The order only becomes real once PayHere confirms payment server-side.
  Future<OrderPayHereCheckout> createPayHereCheckoutForOrder({
    required CartState cart,
    required String addressLine1,
    required String addressLine2,
    required String city,
    required String phone,
    String? couponCode,
    String firstName = 'Customer',
    String lastName = 'MND',
    String email = '',
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to place an order.');
    }
    if (cart.isEmpty) {
      throw StateError('Your cart is empty.');
    }
    final Map<String, dynamic>? payload = _buildOrderPayload(
      cart: cart,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      phone: phone,
      couponCode: couponCode,
    );
    if (payload == null) {
      throw StateError('Missing store for this cart.');
    }
    payload['firstName'] = firstName;
    payload['lastName'] = lastName;
    payload['email'] = email;

    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('createPayHereCheckoutForOrder')
        .call(payload);
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
    return OrderPayHereCheckout.fromCallable(data);
  }

  /// Lets a customer pay online for an order they already placed as Cash on
  /// Delivery. Reuses the order's existing total/id — the order is only
  /// marked paid once PayHere confirms payment server-side.
  Future<OrderPayHereCheckout> createPayHereCheckoutForExistingOrder({
    required String orderId,
    String firstName = 'Customer',
    String lastName = 'MND',
    String email = '',
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to pay for this order.');
    }
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('createPayHereCheckoutForExistingOrder')
        .call(<String, dynamic>{
      'orderId': orderId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
    });
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(result.data as Map<dynamic, dynamic>);
    return OrderPayHereCheckout.fromCallable(data);
  }
}
