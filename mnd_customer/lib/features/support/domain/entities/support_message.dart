import 'package:cloud_firestore/cloud_firestore.dart';

enum SupportSender { customer, staff }

/// One message in `support_threads/{uid}/messages`.
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final SupportSender sender;
  final String text;
  final DateTime? createdAt;

  factory SupportMessage.fromFirestore(String id, Map<String, dynamic> data) {
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    return SupportMessage(
      id: id,
      sender: (data['senderType'] as String?)?.trim() == 'staff'
          ? SupportSender.staff
          : SupportSender.customer,
      text: (data['text'] as String?)?.trim() ?? '',
      createdAt: ts?.toDate(),
    );
  }
}
