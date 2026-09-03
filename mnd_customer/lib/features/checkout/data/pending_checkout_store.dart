import 'dart:convert';

import 'package:mnd_delivery_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kPendingCheckoutPrefsKey = 'pending_checkout_v1';

/// How long a saved checkout attempt stays resumable. Well past a realistic
/// "went to pay, came back" round trip, short enough that a customer who
/// abandons checkout for good doesn't see it resurrected days later.
const Duration kPendingCheckoutExpiry = Duration(hours: 1);

/// Snapshot of an in-progress checkout, saved right before a web browser
/// redirect to PayHere's hosted checkout page. A full-page redirect wipes
/// all in-memory app state (cart, address fields) when the browser later
/// navigates back, so this is what lets the checkout page restore itself
/// instead of the customer landing on an empty cart / the home page.
class PendingCheckoutSnapshot {
  const PendingCheckoutSnapshot({
    required this.items,
    required this.fulfillmentMode,
    required this.deliveryNote,
    required this.specialInstructions,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.phone,
    required this.savedAt,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.couponCode,
    this.pendingOrderId,
    this.pendingTrackingNumber,
  });

  final List<CartItem> items;
  final FulfillmentMode fulfillmentMode;
  final String deliveryNote;
  final String specialInstructions;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final String? couponCode;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String phone;
  final DateTime savedAt;

  /// The draft order created for the abandoned online-payment attempt, if
  /// any — shown to the customer on resume so they can check whether it
  /// actually went through before placing a new (e.g. COD) order.
  final String? pendingOrderId;
  final String? pendingTrackingNumber;

  bool get isExpired => DateTime.now().difference(savedAt) > kPendingCheckoutExpiry;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'items': items
          .map(
            (CartItem i) => <String, dynamic>{
              'productKey': i.productKey,
              'productName': i.productName,
              'storeId': i.storeId,
              'storeName': i.storeName,
              'imageUrl': i.imageUrl,
              'selectedSize': i.selectedSize,
              'quantity': i.quantity,
              'basePrice': i.basePrice,
              'sizePriceDelta': i.sizePriceDelta,
              'extras': i.extras
                  .map(
                    (CartExtra e) => <String, dynamic>{
                      'name': e.name,
                      'priceDelta': e.priceDelta,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'fulfillmentMode': fulfillmentMode.firestoreValue,
      'deliveryNote': deliveryNote,
      'specialInstructions': specialInstructions,
      'dropoffLatitude': dropoffLatitude,
      'dropoffLongitude': dropoffLongitude,
      'couponCode': couponCode,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'phone': phone,
      'pendingOrderId': pendingOrderId,
      'pendingTrackingNumber': pendingTrackingNumber,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  static PendingCheckoutSnapshot? fromJson(Map<String, dynamic> json) {
    try {
      final List<dynamic> rawItems = json['items'] as List<dynamic>? ?? const [];
      final List<CartItem> items = rawItems.map((dynamic raw) {
        final Map<String, dynamic> m = raw as Map<String, dynamic>;
        final List<dynamic> rawExtras =
            m['extras'] as List<dynamic>? ?? const [];
        return CartItem(
          productKey: m['productKey'] as String? ?? '',
          productName: m['productName'] as String? ?? '',
          storeId: m['storeId'] as String? ?? '',
          storeName: m['storeName'] as String? ?? '',
          imageUrl: m['imageUrl'] as String? ?? '',
          selectedSize: m['selectedSize'] as String? ?? '',
          quantity: (m['quantity'] as num?)?.toInt() ?? 1,
          basePrice: (m['basePrice'] as num?)?.toInt() ?? 0,
          sizePriceDelta: (m['sizePriceDelta'] as num?)?.toInt() ?? 0,
          extras: rawExtras.map((dynamic e) {
            final Map<String, dynamic> em = e as Map<String, dynamic>;
            return CartExtra(
              name: em['name'] as String? ?? '',
              priceDelta: (em['priceDelta'] as num?)?.toInt() ?? 0,
            );
          }).toList(),
        );
      }).toList();
      if (items.isEmpty) {
        return null;
      }
      final DateTime? savedAt = DateTime.tryParse(json['savedAt'] as String? ?? '');
      if (savedAt == null) {
        return null;
      }
      return PendingCheckoutSnapshot(
        items: items,
        fulfillmentMode:
            FulfillmentModeX.fromFirestore(json['fulfillmentMode'] as String?),
        deliveryNote: json['deliveryNote'] as String? ?? '',
        specialInstructions: json['specialInstructions'] as String? ?? '',
        dropoffLatitude: (json['dropoffLatitude'] as num?)?.toDouble(),
        dropoffLongitude: (json['dropoffLongitude'] as num?)?.toDouble(),
        couponCode: json['couponCode'] as String?,
        addressLine1: json['addressLine1'] as String? ?? '',
        addressLine2: json['addressLine2'] as String? ?? '',
        city: json['city'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        pendingOrderId: json['pendingOrderId'] as String?,
        pendingTrackingNumber: json['pendingTrackingNumber'] as String?,
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }
}

class PendingCheckoutStore {
  PendingCheckoutStore._();

  static Future<void> save(PendingCheckoutSnapshot snapshot) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kPendingCheckoutPrefsKey,
      jsonEncode(snapshot.toJson()),
    );
  }

  /// Loads the saved snapshot, if any and not expired. Does NOT clear it —
  /// callers that consume it (restore into the cart/form) are responsible
  /// for calling [clear] once they've used it.
  static Future<PendingCheckoutSnapshot?> peek() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(kPendingCheckoutPrefsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    PendingCheckoutSnapshot? snapshot;
    try {
      snapshot = PendingCheckoutSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      snapshot = null;
    }
    if (snapshot == null || snapshot.isExpired) {
      await clear();
      return null;
    }
    return snapshot;
  }

  static Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPendingCheckoutPrefsKey);
  }
}
