/// Vehicle types for MND riders.
enum RiderVehicleType {
  bike('bike', 'Bike'),
  threeWheeler('three_wheeler', 'Three Wheeler'),
  car('car', 'Car'),
  van('van', 'Van');

  const RiderVehicleType(this.firestoreValue, this.label);

  final String firestoreValue;
  final String label;

  /// Passenger trip `vehicleType` values this rider can claim.
  List<String> get passengerTripVehicleTypes {
    return switch (this) {
      RiderVehicleType.bike => const <String>['bike'],
      RiderVehicleType.threeWheeler => const <String>['wheel'],
      RiderVehicleType.car => const <String>['car'],
      RiderVehicleType.van => const <String>['car'],
    };
  }

  static RiderVehicleType? fromFirestore(String? raw) {
    final String v = (raw ?? '').trim().toLowerCase();
    for (final RiderVehicleType t in RiderVehicleType.values) {
      if (t.firestoreValue == v) {
        return t;
      }
    }
    return null;
  }
}
