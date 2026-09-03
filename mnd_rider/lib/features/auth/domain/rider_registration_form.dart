import 'dart:typed_data';

import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';

/// Vehicle photo angles required at registration (matches admin `vehiclePhotos`).
enum RiderVehiclePhotoSide {
  front,
  back,
  left,
  right;

  String get firestoreKey => name;

  String get label {
    switch (this) {
      case RiderVehiclePhotoSide.front:
        return 'Front';
      case RiderVehiclePhotoSide.back:
        return 'Back';
      case RiderVehiclePhotoSide.left:
        return 'Left side';
      case RiderVehiclePhotoSide.right:
        return 'Right side';
    }
  }

  String get hint {
    switch (this) {
      case RiderVehiclePhotoSide.front:
        return 'Clear front view of your vehicle';
      case RiderVehiclePhotoSide.back:
        return 'Clear rear view of your vehicle';
      case RiderVehiclePhotoSide.left:
        return 'Clear left-side view';
      case RiderVehiclePhotoSide.right:
        return 'Clear right-side view';
    }
  }

  String get fieldErrorKey => 'vehiclePhoto_$name';
}

/// In-memory registration form before Firebase writes.
class RiderRegistrationForm {
  const RiderRegistrationForm({
    this.fullName = '',
    this.phone = '',
    this.nicNumber = '',
    this.vehicleType,
    this.vehicleNumber = '',
    this.city = '',
    this.profilePhotoBytes,
    this.licensePhotoBytes,
    this.licenseExpiresAt,
    this.vehiclePhotoFrontBytes,
    this.vehiclePhotoBackBytes,
    this.vehiclePhotoLeftBytes,
    this.vehiclePhotoRightBytes,
    this.insurancePhotoBytes,
    this.insuranceExpiresAt,
    this.revenueLicensePhotoBytes,
    this.revenueLicenseExpiresAt,
  });

  final String fullName;
  final String phone;
  final String nicNumber;
  final RiderVehicleType? vehicleType;
  final String vehicleNumber;
  final String city;
  final Uint8List? profilePhotoBytes;
  final Uint8List? licensePhotoBytes;
  final DateTime? licenseExpiresAt;
  final Uint8List? vehiclePhotoFrontBytes;
  final Uint8List? vehiclePhotoBackBytes;
  final Uint8List? vehiclePhotoLeftBytes;
  final Uint8List? vehiclePhotoRightBytes;
  final Uint8List? insurancePhotoBytes;
  final DateTime? insuranceExpiresAt;
  final Uint8List? revenueLicensePhotoBytes;
  final DateTime? revenueLicenseExpiresAt;

  Uint8List? vehiclePhotoBytesFor(RiderVehiclePhotoSide side) {
    switch (side) {
      case RiderVehiclePhotoSide.front:
        return vehiclePhotoFrontBytes;
      case RiderVehiclePhotoSide.back:
        return vehiclePhotoBackBytes;
      case RiderVehiclePhotoSide.left:
        return vehiclePhotoLeftBytes;
      case RiderVehiclePhotoSide.right:
        return vehiclePhotoRightBytes;
    }
  }

  bool get hasAllVehiclePhotos => RiderVehiclePhotoSide.values.every(
        (RiderVehiclePhotoSide side) {
          final Uint8List? bytes = vehiclePhotoBytesFor(side);
          return bytes != null && bytes.isNotEmpty;
        },
      );

  RiderRegistrationForm copyWith({
    String? fullName,
    String? phone,
    String? nicNumber,
    RiderVehicleType? vehicleType,
    String? vehicleNumber,
    String? city,
    Uint8List? profilePhotoBytes,
    Uint8List? licensePhotoBytes,
    DateTime? licenseExpiresAt,
    Uint8List? vehiclePhotoFrontBytes,
    Uint8List? vehiclePhotoBackBytes,
    Uint8List? vehiclePhotoLeftBytes,
    Uint8List? vehiclePhotoRightBytes,
    Uint8List? insurancePhotoBytes,
    DateTime? insuranceExpiresAt,
    Uint8List? revenueLicensePhotoBytes,
    DateTime? revenueLicenseExpiresAt,
    bool clearProfilePhoto = false,
    bool clearLicensePhoto = false,
    bool clearLicenseExpiresAt = false,
    bool clearVehiclePhotoFront = false,
    bool clearVehiclePhotoBack = false,
    bool clearVehiclePhotoLeft = false,
    bool clearVehiclePhotoRight = false,
    bool clearInsurancePhoto = false,
    bool clearInsuranceExpiresAt = false,
    bool clearRevenueLicensePhoto = false,
    bool clearRevenueLicenseExpiresAt = false,
  }) {
    return RiderRegistrationForm(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      nicNumber: nicNumber ?? this.nicNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      city: city ?? this.city,
      profilePhotoBytes:
          clearProfilePhoto ? null : (profilePhotoBytes ?? this.profilePhotoBytes),
      licensePhotoBytes:
          clearLicensePhoto ? null : (licensePhotoBytes ?? this.licensePhotoBytes),
      licenseExpiresAt: clearLicenseExpiresAt
          ? null
          : (licenseExpiresAt ?? this.licenseExpiresAt),
      vehiclePhotoFrontBytes: clearVehiclePhotoFront
          ? null
          : (vehiclePhotoFrontBytes ?? this.vehiclePhotoFrontBytes),
      vehiclePhotoBackBytes: clearVehiclePhotoBack
          ? null
          : (vehiclePhotoBackBytes ?? this.vehiclePhotoBackBytes),
      vehiclePhotoLeftBytes: clearVehiclePhotoLeft
          ? null
          : (vehiclePhotoLeftBytes ?? this.vehiclePhotoLeftBytes),
      vehiclePhotoRightBytes: clearVehiclePhotoRight
          ? null
          : (vehiclePhotoRightBytes ?? this.vehiclePhotoRightBytes),
      insurancePhotoBytes: clearInsurancePhoto
          ? null
          : (insurancePhotoBytes ?? this.insurancePhotoBytes),
      insuranceExpiresAt: clearInsuranceExpiresAt
          ? null
          : (insuranceExpiresAt ?? this.insuranceExpiresAt),
      revenueLicensePhotoBytes: clearRevenueLicensePhoto
          ? null
          : (revenueLicensePhotoBytes ?? this.revenueLicensePhotoBytes),
      revenueLicenseExpiresAt: clearRevenueLicenseExpiresAt
          ? null
          : (revenueLicenseExpiresAt ?? this.revenueLicenseExpiresAt),
    );
  }
}
