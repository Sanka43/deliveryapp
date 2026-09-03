import 'package:cloud_firestore/cloud_firestore.dart';

/// Offer approval lifecycle. Expired is computed from [VendorOffer.endsAt], not stored.
class VendorOfferStatus {
  VendorOfferStatus._();

  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';

  static bool isKnown(String value) =>
      value == pending || value == approved || value == rejected;
}

/// Standalone shop offer (not a product-line discount).
class VendorOffer {
  const VendorOffer({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.priceLkr,
    required this.endsAt,
    required this.status,
    required this.order,
    required this.createdBy,
    this.rejectionReason,
    this.approvedAt,
    this.approvedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String storeId;
  final String storeName;
  final String title;
  final String description;
  final String imageUrl;
  final int priceLkr;
  final DateTime endsAt;
  final String status;
  final int order;
  final String createdBy;
  final String? rejectionReason;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isExpired => !endsAt.isAfter(DateTime.now());

  bool get isLive => status == VendorOfferStatus.approved && !isExpired;

  String get displayStatus {
    if (status == VendorOfferStatus.approved && isExpired) {
      return 'expired';
    }
    return status;
  }

  factory VendorOffer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> map = doc.data() ?? <String, dynamic>{};
    return VendorOffer.fromMap(doc.id, map);
  }

  factory VendorOffer.fromMap(String id, Map<String, dynamic> map) {
    final dynamic rawPrice = map['priceLkr'] ?? map['price'];
    int price = 0;
    if (rawPrice is num) {
      price = rawPrice.round();
    } else if (rawPrice is String) {
      price = int.tryParse(rawPrice.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    }

    final dynamic rawOrder = map['order'];
    final int order = rawOrder is num ? rawOrder.round() : 0;

    final String statusRaw =
        ((map['status'] as String?) ?? VendorOfferStatus.pending).trim().toLowerCase();
    final String status =
        VendorOfferStatus.isKnown(statusRaw) ? statusRaw : VendorOfferStatus.pending;

    return VendorOffer(
      id: id,
      storeId: ((map['storeId'] as String?) ?? '').trim(),
      storeName: ((map['storeName'] as String?) ?? 'Store').trim(),
      title: ((map['title'] as String?) ?? 'Offer').trim(),
      description: ((map['description'] as String?) ?? '').trim(),
      imageUrl: ((map['imageUrl'] as String?) ?? '').trim(),
      priceLkr: price.clamp(0, 99999999),
      endsAt: _readDate(map['endsAt']) ?? DateTime.now(),
      status: status,
      order: order,
      createdBy: ((map['createdBy'] as String?) ?? '').trim(),
      rejectionReason: (map['rejectionReason'] as String?)?.trim(),
      approvedAt: _readDate(map['approvedAt']),
      approvedBy: (map['approvedBy'] as String?)?.trim(),
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreCreate({
    required FieldValue createdAt,
    required FieldValue updatedAt,
  }) {
    return <String, dynamic>{
      'storeId': storeId,
      'storeName': storeName,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'priceLkr': priceLkr,
      'endsAt': Timestamp.fromDate(endsAt),
      'status': VendorOfferStatus.pending,
      'order': order,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toFirestoreUpdate({
    required FieldValue updatedAt,
    required String status,
  }) {
    return <String, dynamic>{
      'storeId': storeId,
      'storeName': storeName,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'priceLkr': priceLkr,
      'endsAt': Timestamp.fromDate(endsAt),
      'status': status,
      'order': order,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
      'rejectionReason': FieldValue.delete(),
      'approvedAt': FieldValue.delete(),
      'approvedBy': FieldValue.delete(),
    };
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }
}
