/// Maps backend [status] strings onto the visual fulfillment pipeline (non-cancelled orders).
class OrderTimelineLogic {
  OrderTimelineLogic._();

  static const List<OrderTimelineStepDefinition> pipelineSteps =
      <OrderTimelineStepDefinition>[
    OrderTimelineStepDefinition(
      phaseIndex: 0,
      statusKeys: <String>{'placed'},
      title: 'Order placed',
      subtitle: 'We received your order.',
      iconKey: 'shopping_bag',
    ),
    OrderTimelineStepDefinition(
      phaseIndex: 1,
      statusKeys: <String>{'confirmed'},
      title: 'Confirmed',
      subtitle: 'The store accepted your order.',
      iconKey: 'fact_check',
    ),
    OrderTimelineStepDefinition(
      phaseIndex: 2,
      statusKeys: <String>{'preparing'},
      title: 'Preparing',
      subtitle: 'Your items are being prepared.',
      iconKey: 'restaurant',
    ),
    OrderTimelineStepDefinition(
      phaseIndex: 3,
      statusKeys: <String>{'ready'},
      title: 'Ready for pickup',
      subtitle: 'Waiting for the rider.',
      iconKey: 'inventory',
    ),
    OrderTimelineStepDefinition(
      phaseIndex: 4,
      statusKeys: <String>{'out_for_delivery', 'on_the_way'},
      title: 'Out for delivery',
      subtitle: 'On the way to you.',
      iconKey: 'delivery',
    ),
    OrderTimelineStepDefinition(
      phaseIndex: 5,
      statusKeys: <String>{'delivered'},
      title: 'Delivered',
      subtitle: 'Enjoy your order!',
      iconKey: 'home',
    ),
  ];

  /// Self-pickup: Placed → Confirmed → Preparing → Ready → Collected.
  static const List<DeliveryTrackerStepDefinition> pickupTrackerSteps =
      <DeliveryTrackerStepDefinition>[
    DeliveryTrackerStepDefinition(
      stepIndex: 0,
      statusKeys: <String>{'placed', 'confirmed'},
      title: 'Placed',
      subtitle: 'The store has your order.',
      iconKey: 'shopping_bag',
    ),
    DeliveryTrackerStepDefinition(
      stepIndex: 1,
      statusKeys: <String>{'preparing'},
      title: 'Preparing',
      subtitle: 'Your items are being prepared.',
      iconKey: 'restaurant',
    ),
    DeliveryTrackerStepDefinition(
      stepIndex: 2,
      statusKeys: <String>{'ready'},
      title: 'Ready',
      subtitle: 'Come collect at the store.',
      iconKey: 'inventory',
    ),
    DeliveryTrackerStepDefinition(
      stepIndex: 3,
      statusKeys: <String>{'completed'},
      title: 'Collected',
      subtitle: 'Enjoy your order!',
      iconKey: 'home',
    ),
  ];

  static bool isCancelled(String statusRaw) {
    return statusRaw.toLowerCase().trim() == 'cancelled';
  }

  /// A PayHere checkout draft that was never actually placed — no vendor has
  /// seen it and nothing is being prepared. Distinct from every real
  /// pipeline status so trackers don't default it to "Preparing".
  static bool isAwaitingPayment(String statusRaw) {
    return statusRaw.toLowerCase().trim() == 'draft_payment';
  }

  /// Whether the order may show live rider map (not finished / not cancelled / not pickup).
  static bool isActiveForLiveRiderMap(
    String statusRaw, {
    bool isSelfPickup = false,
  }) {
    if (isSelfPickup) {
      return false;
    }
    final String key = statusRaw.toLowerCase().trim();
    if (isCancelled(key) || key == 'delivered' || key == 'completed') {
      return false;
    }
    return true;
  }

  /// Four-step customer tracker: Preparing → Picked up → On the way → Delivered.
  static const List<DeliveryTrackerStepDefinition> deliveryTrackerSteps =
      <DeliveryTrackerStepDefinition>[
    DeliveryTrackerStepDefinition(
      stepIndex: 0,
      statusKeys: <String>{'placed', 'confirmed', 'preparing'},
      title: 'Preparing',
      subtitle: 'The kitchen is working on your order.',
      iconKey: 'restaurant',
    ),
    DeliveryTrackerStepDefinition(
      stepIndex: 1,
      statusKeys: <String>{'ready', 'picked_up'},
      title: 'Picked up',
      subtitle: 'Your order is with the rider.',
      iconKey: 'takeout',
    ),
    DeliveryTrackerStepDefinition(
      stepIndex: 2,
      statusKeys: <String>{'out_for_delivery', 'on_the_way'},
      title: 'On the way',
      subtitle: 'Heading to your address.',
      iconKey: 'delivery',
    ),
    DeliveryTrackerStepDefinition(
      stepIndex: 3,
      statusKeys: <String>{'delivered'},
      title: 'Delivered',
      subtitle: 'Enjoy your meal!',
      iconKey: 'home',
    ),
  ];

  static List<DeliveryTrackerStepDefinition> trackerStepsFor({
    required bool isSelfPickup,
  }) {
    return isSelfPickup ? pickupTrackerSteps : deliveryTrackerSteps;
  }

  /// Active step index 0–3 for the active tracker. Unknown → 0.
  static int currentDeliveryTrackerIndex(
    String statusRaw, {
    bool isSelfPickup = false,
  }) {
    final String key = statusRaw.toLowerCase().trim();
    if (isCancelled(key)) {
      return 0;
    }
    final List<DeliveryTrackerStepDefinition> steps =
        trackerStepsFor(isSelfPickup: isSelfPickup);
    int best = 0;
    for (final DeliveryTrackerStepDefinition step in steps) {
      if (step.statusKeys.contains(key)) {
        best = step.stepIndex;
      }
    }
    return best;
  }

  /// Highest phase index (0–5) implied by [statusRaw]. Unknown statuses fall back to `placed` (0).
  static int currentPhaseIndex(String statusRaw) {
    final String key = statusRaw.toLowerCase().trim();
    if (isCancelled(key)) {
      return 0;
    }
    int best = 0;
    for (final OrderTimelineStepDefinition step in pipelineSteps) {
      if (step.statusKeys.contains(key)) {
        best = step.phaseIndex;
      }
    }
    return best;
  }
}

class DeliveryTrackerStepDefinition {
  const DeliveryTrackerStepDefinition({
    required this.stepIndex,
    required this.statusKeys,
    required this.title,
    required this.subtitle,
    required this.iconKey,
  });

  final int stepIndex;
  final Set<String> statusKeys;
  final String title;
  final String subtitle;
  final String iconKey;
}

class OrderTimelineStepDefinition {
  const OrderTimelineStepDefinition({
    required this.phaseIndex,
    required this.statusKeys,
    required this.title,
    required this.subtitle,
    required this.iconKey,
  });

  final int phaseIndex;
  final Set<String> statusKeys;
  final String title;
  final String subtitle;
  final String iconKey;
}
