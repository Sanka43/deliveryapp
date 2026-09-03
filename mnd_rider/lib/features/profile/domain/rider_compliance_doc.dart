/// The three compliance documents riders must keep current.
enum RiderComplianceDocKind {
  license,
  insurance,
  revenueLicense;

  String get label {
    switch (this) {
      case RiderComplianceDocKind.license:
        return 'Driving license';
      case RiderComplianceDocKind.insurance:
        return 'Insurance';
      case RiderComplianceDocKind.revenueLicense:
        return 'Revenue license';
    }
  }

  /// Firestore field on `riders/{uid}` holding the document photo URL.
  String get photoUrlField {
    switch (this) {
      case RiderComplianceDocKind.license:
        return 'licensePhotoUrl';
      case RiderComplianceDocKind.insurance:
        return 'insurancePhotoUrl';
      case RiderComplianceDocKind.revenueLicense:
        return 'revenueLicensePhotoUrl';
    }
  }

  /// Firestore field on `riders/{uid}` holding the expiry timestamp.
  String get expiresAtField {
    switch (this) {
      case RiderComplianceDocKind.license:
        return 'licenseExpiresAt';
      case RiderComplianceDocKind.insurance:
        return 'insuranceExpiresAt';
      case RiderComplianceDocKind.revenueLicense:
        return 'revenueLicenseExpiresAt';
    }
  }
}

/// Expiry status for one compliance document, as of [daysUntilExpiry].
class RiderComplianceDocStatus {
  const RiderComplianceDocStatus({
    required this.kind,
    required this.expiresAt,
    required this.daysUntilExpiry,
  });

  final RiderComplianceDocKind kind;
  final DateTime? expiresAt;

  /// Calendar-day difference to [expiresAt] (date-only); null if no expiry
  /// date is set yet; negative once past.
  final int? daysUntilExpiry;

  bool get isExpired => daysUntilExpiry != null && daysUntilExpiry! < 0;

  bool get isExpiringSoon =>
      daysUntilExpiry != null && daysUntilExpiry! >= 0 && daysUntilExpiry! <= 14;

  bool get isValid => !isExpired && !isExpiringSoon;
}

/// Computes [RiderComplianceDocStatus] for all three documents (date-only
/// comparison, matching the convention used when these dates are written).
List<RiderComplianceDocStatus> riderComplianceDocStatuses({
  required DateTime? licenseExpiresAt,
  required DateTime? insuranceExpiresAt,
  required DateTime? revenueLicenseExpiresAt,
  DateTime? now,
}) {
  final DateTime today = _dateOnly(now ?? DateTime.now());
  return <RiderComplianceDocStatus>[
    RiderComplianceDocStatus(
      kind: RiderComplianceDocKind.license,
      expiresAt: licenseExpiresAt,
      daysUntilExpiry: _daysUntil(licenseExpiresAt, today),
    ),
    RiderComplianceDocStatus(
      kind: RiderComplianceDocKind.insurance,
      expiresAt: insuranceExpiresAt,
      daysUntilExpiry: _daysUntil(insuranceExpiresAt, today),
    ),
    RiderComplianceDocStatus(
      kind: RiderComplianceDocKind.revenueLicense,
      expiresAt: revenueLicenseExpiresAt,
      daysUntilExpiry: _daysUntil(revenueLicenseExpiresAt, today),
    ),
  ];
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int? _daysUntil(DateTime? expiresAt, DateTime today) {
  if (expiresAt == null) {
    return null;
  }
  return _dateOnly(expiresAt).difference(today).inDays;
}
