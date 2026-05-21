/// Fixed reasons stored on the order document as [cancellationReason].
class OrderCancellationReason {
  const OrderCancellationReason({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  /// Preset options shown in the cancel-order UI (plus optional detail for [other]).
  static const List<OrderCancellationReason> customerOptions =
      <OrderCancellationReason>[
    OrderCancellationReason(
      id: 'changed_mind',
      label: 'Changed my mind',
    ),
    OrderCancellationReason(
      id: 'ordered_wrong',
      label: 'Ordered wrong items or quantity',
    ),
    OrderCancellationReason(
      id: 'delivery_too_slow',
      label: 'Delivery is taking too long',
    ),
    OrderCancellationReason(
      id: 'duplicate_order',
      label: 'Duplicate order',
    ),
    OrderCancellationReason(
      id: 'payment_issue',
      label: 'Payment or checkout issue',
    ),
    OrderCancellationReason(
      id: 'other',
      label: 'Other',
    ),
  ];

  static OrderCancellationReason? byId(String id) {
    final String key = id.trim().toLowerCase();
    for (final OrderCancellationReason r in customerOptions) {
      if (r.id == key) {
        return r;
      }
    }
    return null;
  }
}

/// Whether the customer may cancel from the app for this [statusRaw].
class OrderCancellationPolicy {
  OrderCancellationPolicy._();

  static bool customerMayCancel(String statusRaw) {
    final String s = statusRaw.toLowerCase().trim();
    if (s.isEmpty) {
      return true;
    }
    const Set<String> blocked = <String>{
      'cancelled',
      'delivered',
      'out_for_delivery',
      'on_the_way',
    };
    return !blocked.contains(s);
  }
}

class OrderCancellationResult {
  const OrderCancellationResult._({
    required this.isSuccess,
    this.errorMessage,
  });

  factory OrderCancellationResult.success() {
    return const OrderCancellationResult._(isSuccess: true, errorMessage: null);
  }

  factory OrderCancellationResult.failure(String message) {
    return OrderCancellationResult._(isSuccess: false, errorMessage: message);
  }

  final bool isSuccess;
  final String? errorMessage;
}
