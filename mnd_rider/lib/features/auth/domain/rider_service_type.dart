/// Job categories a rider signs up to receive: food delivery, passenger
/// transport, or both.
enum RiderServiceType {
  foodDelivery('food_delivery', 'Food Delivery'),
  passengerTransport('passenger_transport', 'Passenger Transport');

  const RiderServiceType(this.firestoreValue, this.label);

  final String firestoreValue;
  final String label;

  static RiderServiceType? fromFirestore(String? raw) {
    final String v = (raw ?? '').trim().toLowerCase();
    for (final RiderServiceType t in RiderServiceType.values) {
      if (t.firestoreValue == v) {
        return t;
      }
    }
    return null;
  }
}
