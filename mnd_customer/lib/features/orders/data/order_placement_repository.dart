import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_tracking_number.dart';

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

/// Places a COD order in a single Firestore [transaction]: verifies the vendor
/// is active, then writes `orders/{orderId}`.
class OrderPlacementRepository {
  OrderPlacementRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<OrderPlacementResult> placeCashOnDeliveryOrder({
    required CartState cart,
    required int subtotal,
    required int discount,
    required int deliveryFee,
    required int total,
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
    if (total < 0) {
      return OrderPlacementResult.failure('Invalid order total.');
    }

    final String vendorId = cart.items.first.storeId;
    if (vendorId.isEmpty) {
      return OrderPlacementResult.failure('Missing store for this cart.');
    }

    try {
      final DateTime placedClock = DateTime.now();
      String? builtTracking;
      final String orderId = await _firestore.runTransaction<String>((Transaction transaction) async {
        final DocumentReference<Map<String, dynamic>> vendorRef =
            _firestore.collection(FirebaseCollections.vendors).doc(vendorId);
        final DocumentSnapshot<Map<String, dynamic>> vendorSnap = await transaction.get(vendorRef);
        if (!vendorSnap.exists) {
          throw StateError('This store is no longer available.');
        }
        final Map<String, dynamic>? v = vendorSnap.data();
        final dynamic active = v?['active'];
        if (active != true) {
          throw StateError('This store is not accepting orders right now.');
        }

        final DocumentReference<Map<String, dynamic>> seqRef = _firestore
            .collection(FirebaseCollections.system)
            .doc(FirebaseCollections.orderSequenceDocId);
        final DocumentSnapshot<Map<String, dynamic>> seqSnap = await transaction.get(seqRef);
        int currentSeq = 0;
        if (seqSnap.exists && seqSnap.data() != null) {
          final dynamic rawVal = seqSnap.data()!['value'];
          if (rawVal is int) {
            currentSeq = rawVal;
          } else if (rawVal is num) {
            currentSeq = rawVal.toInt();
          }
        }
        final int nextSeq = currentSeq + 1;
        transaction.set(seqRef, <String, dynamic>{'value': nextSeq});
        final String trackingNumber =
            OrderTrackingNumber.build(placedAt: placedClock, sequence: nextSeq);
        builtTracking = trackingNumber;

        final DocumentReference<Map<String, dynamic>> orderRef =
            _firestore.collection(FirebaseCollections.orders).doc();

        final Map<String, dynamic> payload = <String, dynamic>{
          'trackingNumber': trackingNumber,
          'customerId': user.uid,
          // Same id as vendors/{id} doc and vendors.*.vendorStoreId — dual field names for clarity in Console.
          'vendorId': vendorId,
          'vendorStoreId': vendorId,
          'storeName': cart.items.first.storeName,
          'status': 'placed',
          'paymentMethod': 'cashOnDelivery',
          'items': cart.items.map(_cartItemToMap).toList(growable: false),
          'subtotal': subtotal,
          'discount': discount,
          'deliveryFee': deliveryFee,
          'total': total,
          'deliveryAddress': <String, dynamic>{
            'line1': addressLine1.trim(),
            'line2': addressLine2.trim(),
            'city': city.trim(),
            'phone': phone.trim(),
          },
          'deliveryNote': cart.deliveryNote.trim(),
          'specialInstructions': cart.specialInstructions.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (cart.dropoffLatitude != null && cart.dropoffLongitude != null) {
          payload['dropoffLatitude'] = cart.dropoffLatitude;
          payload['dropoffLongitude'] = cart.dropoffLongitude;
        }

        final String? code = couponCode?.trim();
        if (code != null && code.isNotEmpty) {
          payload['couponCode'] = code;
        }

        transaction.set(orderRef, payload);
        return orderRef.id;
      });

      return OrderPlacementResult.success(orderId, trackingNumber: builtTracking);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return OrderPlacementResult.failure(
          'Could not place order (permission denied). '
          'Sign in with a customer account, ensure Firestore customers/{uid} has role "customer", '
          'and deploy the latest firestore.rules from this project.',
        );
      }
      return OrderPlacementResult.failure(e.message ?? 'Could not place order.');
    } on StateError catch (e) {
      return OrderPlacementResult.failure(e.message);
    } catch (e) {
      return OrderPlacementResult.failure(e.toString());
    }
  }

  static Map<String, dynamic> _cartItemToMap(CartItem item) {
    return <String, dynamic>{
      'productKey': item.productKey,
      'productName': item.productName,
      'storeId': item.storeId,
      'storeName': item.storeName,
      'imageUrl': item.imageUrl,
      'selectedSize': item.selectedSize,
      'quantity': item.quantity,
      'basePrice': item.basePrice,
      'sizePriceDelta': item.sizePriceDelta,
      'extras': item.extras
          .map(
            (CartExtra e) => <String, dynamic>{
              'name': e.name,
              'priceDelta': e.priceDelta,
            },
          )
          .toList(growable: false),
      'unitPrice': item.unitPrice,
      'lineTotal': item.totalPrice,
    };
  }
}
