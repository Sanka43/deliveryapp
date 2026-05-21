/// Active leg of a delivery trip (UI + map targeting).
enum RiderTripPhase {
  /// Heading to vendor / store pickup.
  navigateToVendor,

  /// At vendor; confirm pickup.
  atVendor,

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
}
