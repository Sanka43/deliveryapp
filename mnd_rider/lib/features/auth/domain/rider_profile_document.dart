import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';

/// Firestore `riders/{uid}` document.
class RiderProfileDocument {
  const RiderProfileDocument({
    required this.uid,
    required this.fullName,
    required this.phone,
    required this.nicNumber,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.city,
    required this.registrationComplete,
    this.profilePhotoUrl,
    this.licensePhotoUrl,
    this.email,
    this.status = 'pending',
    this.online = false,
  });

  final String uid;
  final String fullName;
  final String phone;
  final String nicNumber;
  final RiderVehicleType vehicleType;
  final String vehicleNumber;
  final String city;
  final bool registrationComplete;
  final String? profilePhotoUrl;
  final String? licensePhotoUrl;
  final String? email;
  final String status;
  final bool online;

  bool get isRegistrationComplete {
    if (registrationComplete) {
      return true;
    }
    return fullName.isNotEmpty &&
        phone.isNotEmpty &&
        nicNumber.isNotEmpty &&
        vehicleNumber.isNotEmpty;
  }

  /// Admin must set status to `approved` or `active` before going online / taking jobs.
  bool get isApprovedToDrive {
    final String normalized = status.trim().toLowerCase();
    return normalized == 'approved' || normalized == 'active';
  }

  bool get isPendingApproval => !isApprovedToDrive && !isRejected;

  bool get isRejected => status.trim().toLowerCase() == 'rejected';

  String get approvalStatusLabel {
    if (isApprovedToDrive) {
      return 'Approved';
    }
    if (isRejected) {
      return 'Rejected';
    }
    return 'Pending approval';
  }

  factory RiderProfileDocument.fromFirestore(String uid, Map<String, dynamic> data) {
    return RiderProfileDocument(
      uid: uid,
      fullName: (data['fullName'] as String?)?.trim() ?? '',
      phone: (data['phone'] as String?)?.trim() ?? '',
      nicNumber: (data['nicNumber'] as String?)?.trim() ?? '',
      vehicleType: RiderVehicleType.fromFirestore(data['vehicleType'] as String?) ??
          RiderVehicleType.bike,
      vehicleNumber: (data['vehicleNumber'] as String?)?.trim() ?? '',
      city: (data['city'] as String?)?.trim() ?? '',
      registrationComplete: data['registrationComplete'] == true,
      profilePhotoUrl: (data['profilePhotoUrl'] as String?)?.trim(),
      licensePhotoUrl: (data['licensePhotoUrl'] as String?)?.trim(),
      email: (data['email'] as String?)?.trim(),
      status: (data['status'] as String?)?.trim() ?? 'pending',
      online: data['online'] == true,
    );
  }
}
