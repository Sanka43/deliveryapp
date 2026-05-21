/// Vehicle types for MND riders.
enum RiderVehicleType {
  bike('bike', 'Bike'),
  threeWheeler('three_wheeler', 'Three Wheeler'),
  van('van', 'Van');

  const RiderVehicleType(this.firestoreValue, this.label);

  final String firestoreValue;
  final String label;

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
