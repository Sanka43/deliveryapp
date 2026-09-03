enum VendorOrderStatus {
  placed('placed'),
  confirmed('confirmed'),
  preparing('preparing'),
  ready('ready'),
  completed('completed'),
  delivered('delivered'),
  cancelled('cancelled');

  const VendorOrderStatus(this.key);

  final String key;

  static VendorOrderStatus? parse(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    for (final VendorOrderStatus status in values) {
      if (status.key == normalized) {
        return status;
      }
    }
    return null;
  }

  static bool isKnown(String? value) => parse(value) != null;

  static bool isTerminal(String? value) {
    final VendorOrderStatus? status = parse(value);
    return status == VendorOrderStatus.completed ||
        status == VendorOrderStatus.delivered ||
        status == VendorOrderStatus.cancelled;
  }

  static bool isIncoming(String? value) =>
      parse(value) == VendorOrderStatus.placed;

  static bool isKitchen(String? value) {
    final VendorOrderStatus? status = parse(value);
    return status == VendorOrderStatus.confirmed ||
        status == VendorOrderStatus.preparing;
  }

  static bool isReadyForPickup(String? value) =>
      parse(value) == VendorOrderStatus.ready;

  /// Rider has claimed / is en route (not yet delivered).
  static bool isWithRider(String? value) {
    final String s = (value ?? '').trim().toLowerCase();
    return s == 'out_for_delivery' ||
        s == 'picked_up' ||
        s == 'on_the_way';
  }

  static bool isCompleted(String? value) =>
      parse(value) == VendorOrderStatus.completed ||
      parse(value) == VendorOrderStatus.delivered;

  static bool isCancelled(String? value) =>
      parse(value) == VendorOrderStatus.cancelled;

  static bool opensRiderMatching({
    required String status,
    required String fulfillmentMode,
  }) {
    return parse(status) == VendorOrderStatus.ready &&
        fulfillmentMode.trim() != 'selfPickup';
  }

  static bool canVendorTransition({
    required String? from,
    required String to,
    String fulfillmentMode = 'delivery',
    bool hasAssignedRider = false,
  }) {
    final VendorOrderStatus? current = parse(from);
    final VendorOrderStatus? next = parse(to);
    if (next == null) {
      return false;
    }
    if (hasAssignedRider && next == VendorOrderStatus.cancelled) {
      return false;
    }
    if (current == null) {
      return next == VendorOrderStatus.confirmed ||
          next == VendorOrderStatus.cancelled;
    }
    if (current == next) {
      return true;
    }
    final bool selfPickup = fulfillmentMode.trim() == 'selfPickup';
    // Cancel is only allowed on a still-new order (not yet accepted). Once
    // it's in the kitchen or ready, the shop has committed to it — no cancel.
    return switch (current) {
      VendorOrderStatus.placed =>
        next == VendorOrderStatus.confirmed ||
            next == VendorOrderStatus.cancelled,
      VendorOrderStatus.confirmed || VendorOrderStatus.preparing =>
        next == VendorOrderStatus.ready,
      VendorOrderStatus.ready =>
        next == VendorOrderStatus.completed && selfPickup,
      VendorOrderStatus.completed ||
      VendorOrderStatus.delivered ||
      VendorOrderStatus.cancelled => false,
    };
  }
}
