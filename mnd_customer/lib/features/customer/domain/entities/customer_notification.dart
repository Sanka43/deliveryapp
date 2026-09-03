import 'package:cloud_firestore/cloud_firestore.dart';

/// In-app inbox row from top-level `notifications/{id}` (Cloud Functions).
class CustomerNotification {
  const CustomerNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
    this.orderId,
    this.tripId,
    this.status,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool read;
  final DateTime? createdAt;
  final String? orderId;
  final String? tripId;
  final String? status;

  factory CustomerNotification.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final String? orderId = (data['orderId'] as String?)?.trim();
    final String? tripId = (data['tripId'] as String?)?.trim();
    final String? status = (data['status'] as String?)?.trim();
    return CustomerNotification(
      id: id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : 'Notification',
      body: (data['body'] as String?)?.trim() ?? '',
      type: (data['type'] as String?)?.trim() ?? 'system',
      read: data['read'] == true,
      createdAt: ts?.toDate(),
      orderId: orderId != null && orderId.isNotEmpty ? orderId : null,
      tripId: tripId != null && tripId.isNotEmpty ? tripId : null,
      status: status != null && status.isNotEmpty ? status : null,
    );
  }
}
