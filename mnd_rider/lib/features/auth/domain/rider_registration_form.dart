import 'dart:typed_data';

import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';

/// In-memory registration form before Firebase writes.
class RiderRegistrationForm {
  const RiderRegistrationForm({
    this.fullName = '',
    this.phone = '',
    this.nicNumber = '',
    this.password = '',
    this.confirmPassword = '',
    this.vehicleType,
    this.vehicleNumber = '',
    this.city = '',
    this.profilePhotoBytes,
    this.licensePhotoBytes,
  });

  final String fullName;
  final String phone;
  final String nicNumber;
  final String password;
  final String confirmPassword;
  final RiderVehicleType? vehicleType;
  final String vehicleNumber;
  final String city;
  final Uint8List? profilePhotoBytes;
  final Uint8List? licensePhotoBytes;

  RiderRegistrationForm copyWith({
    String? fullName,
    String? phone,
    String? nicNumber,
    String? password,
    String? confirmPassword,
    RiderVehicleType? vehicleType,
    String? vehicleNumber,
    String? city,
    Uint8List? profilePhotoBytes,
    Uint8List? licensePhotoBytes,
    bool clearProfilePhoto = false,
    bool clearLicensePhoto = false,
  }) {
    return RiderRegistrationForm(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      nicNumber: nicNumber ?? this.nicNumber,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      city: city ?? this.city,
      profilePhotoBytes:
          clearProfilePhoto ? null : (profilePhotoBytes ?? this.profilePhotoBytes),
      licensePhotoBytes:
          clearLicensePhoto ? null : (licensePhotoBytes ?? this.licensePhotoBytes),
    );
  }
}
