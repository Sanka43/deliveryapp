import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_place.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';

class RideTrip {
  const RideTrip({
    required this.id,
    required this.customerId,
    required this.contactPhone,
    required this.pickup,
    required this.dropoff,
    this.stops = const <RidePlace>[],
    this.currentStopIndex = 0,
    required this.vehicleType,
    required this.distanceKm,
    required this.estimatedFareLkr,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.openForRiders,
    this.driverNote,
    this.fareQuoteId,
    this.riderId,
    this.assignedRiderId,
    this.riderRated = false,
    this.riderRatingStars,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String customerId;
  final String contactPhone;
  final String? driverNote;
  final RidePlace pickup;
  final RidePlace dropoff;

  /// Intermediate stops between pickup and drop-off (0-2), in visit order.
  final List<RidePlace> stops;

  /// How many stops the assigned rider has visited so far — advances only
  /// while `status == 'in_progress'`, independent of `status` itself.
  final int currentStopIndex;
  final String vehicleType;
  final double distanceKm;
  final int estimatedFareLkr;
  final String? fareQuoteId;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final bool openForRiders;
  final String? riderId;
  final String? assignedRiderId;
  final bool riderRated;
  final int? riderRatingStars;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? get effectiveRiderId {
    final String? a = assignedRiderId?.trim();
    if (a != null && a.isNotEmpty) {
      return a;
    }
    final String? r = riderId?.trim();
    if (r != null && r.isNotEmpty) {
      return r;
    }
    return null;
  }

  bool get isActive => RideConstants.activeStatuses.contains(status);

  bool get isTrackable => RideConstants.trackableStatuses.contains(status);

  /// True when the trip has ended, the customer chose to pay online, and
  /// payment hasn't gone through yet — the customer still owes the fare.
  bool get needsOnlinePayment =>
      status == RideConstants.statusCompleted &&
      paymentMethod == RideConstants.paymentPayHere &&
      paymentStatus != 'paid';

  RideVehicleType? get vehicle => RideVehicleType.fromFirestore(vehicleType);

  /// Where the rider is currently heading on this leg — pickup while not
  /// yet in progress, then each stop in order as `currentStopIndex`
  /// advances, then dropoff once every stop has been visited. Mirrors the
  /// rider app's per-leg navigation, so tracking shows the actual next
  /// destination instead of always jumping straight to dropoff.
  RidePlace get currentLegTarget {
    if (status != RideConstants.statusInProgress) {
      return pickup;
    }
    if (currentStopIndex < stops.length) {
      return stops[currentStopIndex];
    }
    return dropoff;
  }

  /// Human label for [currentLegTarget] — "Stop 1", "Stop 2", or "Dropoff".
  String get currentLegLabel {
    if (status != RideConstants.statusInProgress) {
      return pickup.label;
    }
    if (currentStopIndex < stops.length) {
      return 'Stop ${currentStopIndex + 1}: ${stops[currentStopIndex].label}';
    }
    return dropoff.label;
  }

  factory RideTrip.fromDoc(String id, Map<String, dynamic> data) {
    DateTime? readTs(dynamic v) {
      if (v is Timestamp) {
        return v.toDate();
      }
      return null;
    }

    return RideTrip(
      id: id,
      customerId: (data['customerId'] as String?)?.trim() ?? '',
      contactPhone: (data['contactPhone'] as String?)?.trim() ?? '',
      driverNote: (data['driverNote'] as String?)?.trim(),
      pickup: RidePlace.fromMap(
        data['pickup'] is Map
            ? Map<String, dynamic>.from(data['pickup'] as Map)
            : null,
      ),
      dropoff: RidePlace.fromMap(
        data['dropoff'] is Map
            ? Map<String, dynamic>.from(data['dropoff'] as Map)
            : null,
      ),
      stops: data['stops'] is List
          ? (data['stops'] as List<dynamic>)
              .whereType<Map>()
              .map((Map e) => RidePlace.fromMap(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const <RidePlace>[],
      currentStopIndex: (data['currentStopIndex'] as num?)?.toInt() ?? 0,
      vehicleType: (data['vehicleType'] as String?)?.trim() ?? '',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      estimatedFareLkr: (data['estimatedFareLkr'] as num?)?.toInt() ?? 0,
      fareQuoteId: (data['fareQuoteId'] as String?)?.trim(),
      status: (data['status'] as String?)?.trim() ?? '',
      paymentMethod: (data['paymentMethod'] as String?)?.trim() ?? '',
      paymentStatus: (data['paymentStatus'] as String?)?.trim() ?? '',
      openForRiders: data['openForRiders'] == true,
      riderId: (data['riderId'] as String?)?.trim(),
      assignedRiderId: (data['assignedRiderId'] as String?)?.trim(),
      riderRated: data['riderRated'] == true,
      riderRatingStars: (data['riderRatingStars'] as num?)?.toInt(),
      createdAt: readTs(data['createdAt']),
      updatedAt: readTs(data['updatedAt']),
    );
  }
}
