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

  static bool canVendorTransition({required String? from, required String to}) {
    final VendorOrderStatus? current = parse(from);
    final VendorOrderStatus? next = parse(to);
    if (next == null) {
      return false;
    }
    if (current == null) {
      return next == VendorOrderStatus.confirmed ||
          next == VendorOrderStatus.cancelled;
    }
    if (current == next) {
      return true;
    }
    return switch (current) {
      VendorOrderStatus.placed =>
        next == VendorOrderStatus.confirmed ||
            next == VendorOrderStatus.cancelled,
      VendorOrderStatus.confirmed || VendorOrderStatus.preparing =>
        next == VendorOrderStatus.ready || next == VendorOrderStatus.cancelled,
      VendorOrderStatus.ready =>
        next == VendorOrderStatus.completed ||
            next == VendorOrderStatus.cancelled,
      VendorOrderStatus.completed ||
      VendorOrderStatus.delivered ||
      VendorOrderStatus.cancelled => false,
    };
  }
}
