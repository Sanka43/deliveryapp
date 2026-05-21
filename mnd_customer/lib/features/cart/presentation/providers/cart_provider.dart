import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartCoupon {
  const CartCoupon({
    required this.code,
    required this.discountType,
    required this.value,
  });

  final String code;
  final CouponDiscountType discountType;
  final int value;
}

enum CouponDiscountType { flat, percent }

class CartExtra {
  const CartExtra({
    required this.name,
    required this.priceDelta,
  });

  final String name;
  final int priceDelta;
}

class CartItem {
  const CartItem({
    required this.productKey,
    required this.productName,
    required this.storeId,
    required this.storeName,
    required this.imageUrl,
    required this.selectedSize,
    required this.quantity,
    required this.basePrice,
    required this.sizePriceDelta,
    this.extras = const <CartExtra>[],
  });

  final String productKey;
  final String productName;
  final String storeId;
  final String storeName;
  final String imageUrl;
  final String selectedSize;
  final int quantity;
  final int basePrice;
  final int sizePriceDelta;
  final List<CartExtra> extras;

  int get extrasPriceTotal => extras.fold<int>(0, (sum, item) => sum + item.priceDelta);

  int get unitPrice => basePrice + sizePriceDelta + extrasPriceTotal;

  int get totalPrice => unitPrice * quantity;

  String get lineId {
    final String extrasKey = extras.map((extra) => extra.name).join('|');
    return '$productKey::$selectedSize::$extrasKey';
  }

  CartItem copyWith({
    int? quantity,
  }) {
    return CartItem(
      productKey: productKey,
      productName: productName,
      storeId: storeId,
      storeName: storeName,
      imageUrl: imageUrl,
      selectedSize: selectedSize,
      quantity: quantity ?? this.quantity,
      basePrice: basePrice,
      sizePriceDelta: sizePriceDelta,
      extras: extras,
    );
  }
}

class CartState {
  const CartState({
    this.items = const <CartItem>[],
    this.appliedCoupon,
    String? deliveryNote,
    String? specialInstructions,
    this.dropoffLatitude,
    this.dropoffLongitude,
  })  : _deliveryNote = deliveryNote,
        _specialInstructions = specialInstructions;

  final List<CartItem> items;
  final CartCoupon? appliedCoupon;
  final String? _deliveryNote;
  final String? _specialInstructions;

  /// Drop-off from map picker (checkout). Used with vendor coordinates for distance fee.
  final double? dropoffLatitude;
  final double? dropoffLongitude;

  String get deliveryNote => _deliveryNote ?? '';
  String get specialInstructions => _specialInstructions ?? '';

  int get itemCount => items.fold<int>(0, (sum, item) => sum + item.quantity);

  int get subtotal => items.fold<int>(0, (sum, item) => sum + item.totalPrice);

  int get discount {
    final CartCoupon? coupon = appliedCoupon;
    if (coupon == null || subtotal <= 0) {
      return 0;
    }
    if (coupon.discountType == CouponDiscountType.flat) {
      return coupon.value > subtotal ? subtotal : coupon.value;
    }
    final int percentDiscount = (subtotal * coupon.value) ~/ 100;
    return percentDiscount > subtotal ? subtotal : percentDiscount;
  }

  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    CartCoupon? appliedCoupon,
    String? deliveryNote,
    String? specialInstructions,
    double? dropoffLatitude,
    double? dropoffLongitude,
    bool clearDropoff = false,
    bool clearCoupon = false,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
      deliveryNote: deliveryNote ?? this.deliveryNote,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      dropoffLatitude: clearDropoff ? null : (dropoffLatitude ?? this.dropoffLatitude),
      dropoffLongitude: clearDropoff ? null : (dropoffLongitude ?? this.dropoffLongitude),
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  bool addItem(CartItem newItem) {
    if (!canAddItemFromStore(newItem.storeId)) {
      return false;
    }

    final List<CartItem> updatedItems = List<CartItem>.from(state.items);
    final int existingIndex = updatedItems.indexWhere(
      (item) => item.lineId == newItem.lineId,
    );

    if (existingIndex >= 0) {
      final CartItem current = updatedItems[existingIndex];
      updatedItems[existingIndex] = current.copyWith(
        quantity: current.quantity + newItem.quantity,
      );
    } else {
      updatedItems.add(newItem);
    }

    state = state.copyWith(items: updatedItems);
    return true;
  }

  bool canAddItemFromStore(String storeId) {
    if (state.items.isEmpty) {
      return true;
    }
    return state.items.first.storeId == storeId;
  }

  void updateItemQuantity({
    required String lineId,
    required int quantity,
  }) {
    if (quantity <= 0) {
      removeItem(lineId);
      return;
    }

    final List<CartItem> updatedItems = state.items
        .map((item) => item.lineId == lineId ? item.copyWith(quantity: quantity) : item)
        .toList(growable: false);

    state = state.copyWith(items: updatedItems);
  }

  void removeItem(String lineId) {
    final List<CartItem> updatedItems =
        state.items.where((item) => item.lineId != lineId).toList(growable: false);
    state = state.copyWith(
      items: updatedItems,
      clearCoupon: updatedItems.isEmpty,
      clearDropoff: updatedItems.isEmpty,
    );
  }

  void clear() {
    state = const CartState();
  }

  /// Adds [items] when the cart is empty or already for [storeId]. Returns false if another store occupies the cart.
  bool mergeItemsFromSameStore(String storeId, List<CartItem> items) {
    if (items.isEmpty) {
      return true;
    }
    if (!canAddItemFromStore(storeId)) {
      return false;
    }
    for (final CartItem item in items) {
      addItem(item);
    }
    return true;
  }

  /// Replaces the cart with [items] and optional notes / map drop-off (e.g. reorder).
  void replaceCartContents(
    List<CartItem> items, {
    String deliveryNote = '',
    String specialInstructions = '',
    double? dropoffLatitude,
    double? dropoffLongitude,
  }) {
    state = const CartState();
    if (dropoffLatitude != null && dropoffLongitude != null) {
      setDropoffLocation(dropoffLatitude, dropoffLongitude);
    }
    setDeliveryNote(deliveryNote);
    setSpecialInstructions(specialInstructions);
    for (final CartItem item in items) {
      addItem(item);
    }
  }

  void setDropoffLocation(double latitude, double longitude) {
    state = state.copyWith(dropoffLatitude: latitude, dropoffLongitude: longitude);
  }

  void clearDropoffLocation() {
    state = state.copyWith(clearDropoff: true);
  }

  bool applyCouponCode(String code) {
    final String normalizedCode = code.trim().toUpperCase();
    final CartCoupon? coupon = _supportedCoupons[normalizedCode];
    if (coupon == null) {
      return false;
    }
    state = state.copyWith(appliedCoupon: coupon);
    return true;
  }

  void removeCoupon() {
    state = state.copyWith(clearCoupon: true);
  }

  void setDeliveryNote(String value) {
    state = state.copyWith(deliveryNote: value.trim());
  }

  void setSpecialInstructions(String value) {
    state = state.copyWith(specialInstructions: value.trim());
  }
}

final StateNotifierProvider<CartNotifier, CartState> cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((Ref ref) {
  return CartNotifier();
});

final Provider<int> cartItemCountProvider = Provider<int>((Ref ref) {
  return ref.watch(cartProvider).itemCount;
});

final Provider<int> cartSubtotalProvider = Provider<int>((Ref ref) {
  return ref.watch(cartProvider).subtotal;
});

const Map<String, CartCoupon> _supportedCoupons = <String, CartCoupon>{
  'SAVE100': CartCoupon(
    code: 'SAVE100',
    discountType: CouponDiscountType.flat,
    value: 100,
  ),
  'MND10': CartCoupon(
    code: 'MND10',
    discountType: CouponDiscountType.percent,
    value: 10,
  ),
  'WELCOME15': CartCoupon(
    code: 'WELCOME15',
    discountType: CouponDiscountType.percent,
    value: 15,
  ),
};
