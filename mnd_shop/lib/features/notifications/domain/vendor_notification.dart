import 'package:cloud_firestore/cloud_firestore.dart';

/// In-app notification for a vendor (`vendors/{vendorId}/notifications/{id}`).
class VendorNotification {
  const VendorNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
    this.orderId,
  });

  final String id;
  final String title;
  final String body;

  /// e.g. [kTypeOrderNew], [kTypeSystem], [kTypeApproval].
  final String type;
  final bool read;
  final DateTime? createdAt;
  final String? orderId;

  static const String kTypeOrderNew = 'order_new';
  static const String kTypeOrderCancelled = 'order_cancelled';
  static const String kTypeApproval = 'approval';
  static const String kTypeSystem = 'system';

  factory VendorNotification.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    return VendorNotification(
      id: id,
      title: (data['title'] as String?)?.trim() ?? 'Notification',
      body: (data['body'] as String?)?.trim() ?? '',
      type: (data['type'] as String?)?.trim() ?? kTypeSystem,
      read: data['read'] == true,
      createdAt: ts?.toDate(),
      orderId: (data['orderId'] as String?)?.trim(),
    );
  }
}
