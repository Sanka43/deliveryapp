import 'dart:typed_data';

import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';

class RiderProfileEditForm {
  const RiderProfileEditForm({
    this.fullName = '',
    this.phoneLocal = '',
    this.nicNumber = '',
    this.city = '',
    this.vehicleType = RiderVehicleType.bike,
    this.vehicleNumber = '',
    this.newProfilePhotoBytes,
    this.newLicensePhotoBytes,
  });

  final String fullName;
  final String phoneLocal;
  final String nicNumber;
  final String city;
  final RiderVehicleType vehicleType;
  final String vehicleNumber;
  final Uint8List? newProfilePhotoBytes;
  final Uint8List? newLicensePhotoBytes;

  factory RiderProfileEditForm.fromProfile(RiderProfile profile) {
    String local = profile.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (local.startsWith('94') && local.length >= 11) {
      local = local.substring(local.length - 9);
    }
    if (local.length == 10 && local.startsWith('0')) {
      local = local.substring(1);
    }

    return RiderProfileEditForm(
      fullName: profile.fullName,
      phoneLocal: local,
      nicNumber: profile.nicNumber,
      city: profile.city,
      vehicleType: profile.vehicleType,
      vehicleNumber: profile.vehicleNumber,
    );
  }

  RiderProfileEditForm copyWith({
    String? fullName,
    String? phoneLocal,
    String? nicNumber,
    String? city,
    RiderVehicleType? vehicleType,
    String? vehicleNumber,
    Uint8List? newProfilePhotoBytes,
    Uint8List? newLicensePhotoBytes,
    bool clearProfilePhoto = false,
    bool clearLicensePhoto = false,
  }) {
    return RiderProfileEditForm(
      fullName: fullName ?? this.fullName,
      phoneLocal: phoneLocal ?? this.phoneLocal,
      nicNumber: nicNumber ?? this.nicNumber,
      city: city ?? this.city,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      newProfilePhotoBytes: clearProfilePhoto
          ? null
          : (newProfilePhotoBytes ?? this.newProfilePhotoBytes),
      newLicensePhotoBytes: clearLicensePhoto
          ? null
          : (newLicensePhotoBytes ?? this.newLicensePhotoBytes),
    );
  }
}
