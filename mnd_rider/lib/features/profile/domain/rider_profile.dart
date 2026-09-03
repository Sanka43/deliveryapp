import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';

/// Rider profile view model from `riders/{uid}`.
class RiderProfile {
  const RiderProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.nicNumber,
    required this.city,
    required this.vehicleType,
    required this.vehicleNumber,
    this.profilePhotoUrl,
    this.licensePhotoUrl,
    this.licenseExpiresAt,
    this.insurancePhotoUrl,
    this.revenueLicensePhotoUrl,
    this.status = 'pending',
    this.isOnline = false,
    this.registrationComplete = false,
    this.insuranceExpiresAt,
    this.revenueLicenseExpiresAt,
    this.rating = 0,
    this.ratingCount = 0,
    this.acceptsPassengerRides = true,
    this.cashInHandLkr = 0,
    this.cashOwedToAdminLkr = 0,
    this.cashPendingSettlementLkr = 0,
    this.cashHoldActive = false,
  });

  const RiderProfile.guest()
      : uid = '',
        fullName = 'Rider',
        email = '',
        phone = '',
        nicNumber = '',
        city = '',
        vehicleType = RiderVehicleType.bike,
        vehicleNumber = '',
        profilePhotoUrl = null,
        licensePhotoUrl = null,
        licenseExpiresAt = null,
        insurancePhotoUrl = null,
        revenueLicensePhotoUrl = null,
        status = 'pending',
        isOnline = false,
        registrationComplete = false,
        insuranceExpiresAt = null,
        revenueLicenseExpiresAt = null,
        rating = 0,
        ratingCount = 0,
        acceptsPassengerRides = true,
        cashInHandLkr = 0,
        cashOwedToAdminLkr = 0,
        cashPendingSettlementLkr = 0,
        cashHoldActive = false;

  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String nicNumber;
  final String city;
  final RiderVehicleType vehicleType;
  final String vehicleNumber;
  final String? profilePhotoUrl;
  final String? licensePhotoUrl;
  final DateTime? licenseExpiresAt;
  final String? insurancePhotoUrl;
  final String? revenueLicensePhotoUrl;
  final String status;
  final bool isOnline;
  final bool registrationComplete;
  final DateTime? insuranceExpiresAt;
  final DateTime? revenueLicenseExpiresAt;

  /// Average of visible `rider_ratings` (Cloud Function), 1 decimal place.
  final double rating;

  /// Count of visible ratings behind [rating].
  final int ratingCount;

  /// Whether this rider wants to see new passenger-ride offers. Defaults to
  /// true (opt-out preference — missing field means enabled).
  final bool acceptsPassengerRides;

  /// Collected cash the rider has not handed over yet — cash ride fares plus
  /// cash-on-delivery collections. Server-maintained (functions/riderCash.ts).
  final int cashInHandLkr;

  /// The slice of [cashInHandLkr] that must reach admin: shop product cash,
  /// service charge, plus the platform's ride/delivery commission.
  final int cashOwedToAdminLkr;

  /// Locked in a handover that is waiting for admin confirmation.
  final int cashPendingSettlementLkr;

  /// Set once cash in hand goes above the admin-configured limit. While true,
  /// Firestore rules reject any attempt to claim a new ride or delivery.
  final bool cashHoldActive;

  /// Over the cash limit — no new jobs until admin confirms a handover.
  bool get isCashHeld => cashHoldActive;

  /// A handover is already waiting for admin, so "Settle now" is unavailable.
  bool get hasPendingCashSettlement => cashPendingSettlementLkr > 0;

  bool get isApprovedToDrive {
    final String s = status.trim().toLowerCase();
    return s == 'approved' || s == 'active';
  }

  /// True when stored license / insurance / revenue license expiry is in the past.
  bool get hasExpiredDrivingDocs {
    final DateTime now = DateTime.now();
    if (licenseExpiresAt != null && licenseExpiresAt!.isBefore(now)) {
      return true;
    }
    if (insuranceExpiresAt != null && insuranceExpiresAt!.isBefore(now)) {
      return true;
    }
    if (revenueLicenseExpiresAt != null &&
        revenueLicenseExpiresAt!.isBefore(now)) {
      return true;
    }
    return false;
  }

  String get approvalStatusLabel {
    if (isApprovedToDrive) {
      return 'Approved';
    }
    if (status.trim().toLowerCase() == 'rejected') {
      return 'Rejected';
    }
    return 'Pending approval';
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  factory RiderProfile.fromDoc(String uid, Map<String, dynamic> data) {
    return RiderProfile(
      uid: uid,
      fullName: (data['fullName'] as String?)?.trim() ?? 'Rider',
      email: (data['email'] as String?)?.trim() ?? '',
      phone: (data['phone'] as String?)?.trim() ?? '',
      nicNumber: (data['nicNumber'] as String?)?.trim() ?? '',
      city: (data['city'] as String?)?.trim() ?? '',
      vehicleType: RiderVehicleType.fromFirestore(data['vehicleType'] as String?) ??
          RiderVehicleType.bike,
      vehicleNumber: (data['vehicleNumber'] as String?)?.trim() ?? '',
      profilePhotoUrl: (data['profilePhotoUrl'] as String?)?.trim(),
      licensePhotoUrl: (data['licensePhotoUrl'] as String?)?.trim(),
      licenseExpiresAt: _asDateTime(data['licenseExpiresAt']),
      insurancePhotoUrl: (data['insurancePhotoUrl'] as String?)?.trim(),
      revenueLicensePhotoUrl:
          (data['revenueLicensePhotoUrl'] as String?)?.trim(),
      status: (data['status'] as String?)?.trim() ?? 'pending',
      isOnline: data['online'] == true,
      registrationComplete: data['registrationComplete'] == true,
      insuranceExpiresAt: _asDateTime(data['insuranceExpiresAt']),
      revenueLicenseExpiresAt: _asDateTime(data['revenueLicenseExpiresAt']),
      rating: _asDouble(data['rating']),
      ratingCount: _asInt(data['ratingCount']),
      acceptsPassengerRides: data['acceptsPassengerRides'] != false,
      cashInHandLkr: _asInt(data['cashInHandLkr']),
      cashOwedToAdminLkr: _asInt(data['cashOwedToAdminLkr']),
      cashPendingSettlementLkr: _asInt(data['cashPendingSettlementLkr']),
      cashHoldActive: data['cashHoldActive'] == true,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  static int _asInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }
}
