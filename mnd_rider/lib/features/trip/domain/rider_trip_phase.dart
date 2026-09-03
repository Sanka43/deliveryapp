/// Active leg of a delivery or passenger-ride trip (UI + map targeting).
///
/// Stop legs only apply to passenger rides with intermediate stops — a
/// delivery order (vendor→customer) or a stop-less ride never enters them.
enum RiderTripPhase {
  /// Heading to vendor / store pickup.
  navigateToVendor,

  /// At vendor; confirm pickup.
  atVendor,

  /// Heading to the ride's 1st intermediate stop.
  navigateToStop1,

  /// At the ride's 1st intermediate stop.
  atStop1,

  /// Heading to the ride's 2nd intermediate stop.
  navigateToStop2,

  /// At the ride's 2nd intermediate stop.
  atStop2,

  /// Heading to customer dropoff.
  navigateToCustomer,

  /// At customer; confirm delivery.
  atCustomer,
}

extension RiderTripPhaseX on RiderTripPhase {
  bool get isVendorLeg =>
      this == RiderTripPhase.navigateToVendor || this == RiderTripPhase.atVendor;

  bool get isCustomerLeg =>
      this == RiderTripPhase.navigateToCustomer || this == RiderTripPhase.atCustomer;

  bool get isStopLeg =>
      this == RiderTripPhase.navigateToStop1 ||
      this == RiderTripPhase.atStop1 ||
      this == RiderTripPhase.navigateToStop2 ||
      this == RiderTripPhase.atStop2;

  /// 0-based stop index for a stop leg, else null.
  int? get stopIndex => switch (this) {
        RiderTripPhase.navigateToStop1 || RiderTripPhase.atStop1 => 0,
        RiderTripPhase.navigateToStop2 || RiderTripPhase.atStop2 => 1,
        _ => null,
      };

  bool get isArrivedChrome =>
      this == RiderTripPhase.atVendor ||
      this == RiderTripPhase.atStop1 ||
      this == RiderTripPhase.atStop2 ||
      this == RiderTripPhase.atCustomer;
}
