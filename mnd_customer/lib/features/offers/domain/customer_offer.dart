import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerOffer {
  const CustomerOffer({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.priceLkr,
    required this.endsAt,
    required this.order,
  });

  final String id;
  final String storeId;
  final String storeName;
  final String title;
  final String description;
  final String imageUrl;
  final int priceLkr;
  final DateTime endsAt;
  final int order;

  bool get isLive => endsAt.isAfter(DateTime.now());

  factory CustomerOffer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> map = doc.data() ?? <String, dynamic>{};
    final dynamic rawPrice = map['priceLkr'] ?? map['price'];
    int price = 0;
    if (rawPrice is num) {
      price = rawPrice.round();
    }

    DateTime endsAt = DateTime.now();
    final dynamic endsRaw = map['endsAt'];
    if (endsRaw is Timestamp) {
      endsAt = endsRaw.toDate();
    } else if (endsRaw is DateTime) {
      endsAt = endsRaw;
    }

    return CustomerOffer(
      id: doc.id,
      storeId: ((map['storeId'] as String?) ?? '').trim(),
      storeName: ((map['storeName'] as String?) ?? 'Store').trim(),
      title: ((map['title'] as String?) ?? 'Special offer').trim(),
      description: ((map['description'] as String?) ?? '').trim(),
      imageUrl: ((map['imageUrl'] as String?) ?? '').trim(),
      priceLkr: price.clamp(0, 99999999),
      endsAt: endsAt,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }
}
