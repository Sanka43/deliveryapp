/// Passenger ride constants and vehicle catalog (web-beta labels).
class RideConstants {
  RideConstants._();

  static const String vehicleWheel = 'wheel';
  static const String vehicleBike = 'bike';
  static const String vehicleCar = 'car';

  static const String statusDraftPayment = 'draft_payment';
  static const String statusSearching = 'searching';
  static const String statusAccepted = 'accepted';
  static const String statusArrived = 'arrived';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  static const String paymentCash = 'cash';
  static const String paymentPayHere = 'payhere';

  /// Client-only driver-search UX: 3 steps × 30s, then change-vehicle prompt.
  static const int searchStepSeconds = 30;
  static const int searchStepCount = 3;

  static const List<String> activeStatuses = <String>[
    statusDraftPayment,
    statusSearching,
    statusAccepted,
    statusArrived,
    statusInProgress,
  ];

  static const List<String> trackableStatuses = <String>[
    statusAccepted,
    statusArrived,
    statusInProgress,
  ];
}

enum RideVehicleType {
  bike(RideConstants.vehicleBike, 'Bike', 1, 4.8),
  wheel(RideConstants.vehicleWheel, 'Wheel', 3, 4.5),
  car(RideConstants.vehicleCar, 'Car', 4, 4.6);

  const RideVehicleType(
    this.firestoreValue,
    this.label,
    this.capacity,
    this.rating,
  );

  final String firestoreValue;
  final String label;
  final int capacity;
  final double rating;

  static RideVehicleType? fromFirestore(String? raw) {
    final String v = (raw ?? '').trim().toLowerCase();
    for (final RideVehicleType t in RideVehicleType.values) {
      if (t.firestoreValue == v) {
        return t;
      }
    }
    return null;
  }
}
