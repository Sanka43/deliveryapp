import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the single currently-offered item and this-session dismissals for
/// [RiderOrderRequestOverlayHost] — shared between delivery-order offers
/// and passenger-ride offers (both just use plain string ids here; order
/// ids and trip ids never collide since they live in separate collections).
class OrderRequestSessionState {
  const OrderRequestSessionState({
    this.dismissedOrderIds = const <String>{},
    this.activeOrderId,
    this.secondsRemaining = 0,
  });

  final Set<String> dismissedOrderIds;
  final String? activeOrderId;
  final int secondsRemaining;

  OrderRequestSessionState copyWith({
    Set<String>? dismissedOrderIds,
    String? activeOrderId,
    int? secondsRemaining,
    bool clearActive = false,
  }) {
    return OrderRequestSessionState(
      dismissedOrderIds: dismissedOrderIds ?? this.dismissedOrderIds,
      activeOrderId: clearActive ? null : (activeOrderId ?? this.activeOrderId),
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
    );
  }
}

class OrderRequestSessionNotifier extends Notifier<OrderRequestSessionState> {
  @override
  OrderRequestSessionState build() => const OrderRequestSessionState();

  void dismiss(String orderId) {
    final Set<String> next = Set<String>.from(state.dismissedOrderIds)..add(orderId);
    state = state.copyWith(
      dismissedOrderIds: next,
      clearActive: state.activeOrderId == orderId,
      secondsRemaining: 0,
    );
  }

  void setActive(String orderId, int secondsRemaining) {
    state = state.copyWith(
      activeOrderId: orderId,
      secondsRemaining: secondsRemaining,
    );
  }

  void tickCountdown(int secondsRemaining) {
    state = state.copyWith(secondsRemaining: secondsRemaining);
  }

  void clearActive() {
    state = state.copyWith(clearActive: true, secondsRemaining: 0);
  }

  void resetSession() {
    state = const OrderRequestSessionState();
  }
}

final NotifierProvider<OrderRequestSessionNotifier, OrderRequestSessionState>
    orderRequestSessionProvider =
    NotifierProvider<OrderRequestSessionNotifier, OrderRequestSessionState>(
  OrderRequestSessionNotifier.new,
);
