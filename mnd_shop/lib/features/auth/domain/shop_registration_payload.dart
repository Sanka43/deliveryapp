import 'dart:typed_data';

/// Form data collected before Firebase Auth account creation.
class ShopRegistrationPayload {
  const ShopRegistrationPayload({
    required this.shopDisplayName,
    required this.email,
    required this.password,
    required this.phone,
    required this.addressLine,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.shopDescription,
    required this.categoryLabel,
    this.categoryIsGrocery,
    required this.shopTypeLabel,
    required this.openTime,
    required this.closeTime,
    required this.closedSunday,
    required this.openingHoursExtraNote,
    required this.wageKitchenNotes,
    required this.wageCounterNotes,
    required this.wageDeliveryNotes,
    this.whatsapp,
    this.shopPhotos = const <Uint8List?>[],
  });

  final String shopDisplayName;
  final String email;
  final String password;
  final String phone;
  final String? whatsapp;
  final String addressLine;
  final String city;
  final double latitude;
  final double longitude;
  /// Short public shop description (shown in customer app / admin).
  final String shopDescription;
  /// Broad bucket (e.g. Food) — stored as `vendors.category`.
  final String categoryLabel;
  /// Explicit admin-set flag from the selected `shop_categories` doc, when
  /// available — preferred over parsing [categoryLabel] text so renaming a
  /// category can't silently misclassify new vendor registrations. Null
  /// when the category doc predates this field (falls back to text).
  final bool? categoryIsGrocery;
  /// Specific kind (e.g. Rice and curry) — stored as `vendors.tag`.
  final String shopTypeLabel;
  final String openTime;
  final String closeTime;
  final bool closedSunday;
  final String openingHoursExtraNote;
  final String wageKitchenNotes;
  final String wageCounterNotes;
  final String wageDeliveryNotes;

  /// Up to 4 images; at least one required — validated in repository.
  final List<Uint8List?> shopPhotos;

  List<Uint8List> get nonEmptyPhotos =>
      shopPhotos.whereType<Uint8List>().toList(growable: false);
}
