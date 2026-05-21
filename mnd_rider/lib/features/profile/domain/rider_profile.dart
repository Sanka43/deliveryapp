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
    this.status = 'pending',
    this.isOnline = false,
    this.registrationComplete = false,
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
        status = 'pending',
        isOnline = false,
        registrationComplete = false;

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
  final String status;
  final bool isOnline;
  final bool registrationComplete;

  bool get isApprovedToDrive {
    final String s = status.trim().toLowerCase();
    return s == 'approved' || s == 'active';
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
      status: (data['status'] as String?)?.trim() ?? 'pending',
      isOnline: data['online'] == true,
      registrationComplete: data['registrationComplete'] == true,
    );
  }
}
