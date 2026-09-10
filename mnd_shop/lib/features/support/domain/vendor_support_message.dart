import 'package:cloud_firestore/cloud_firestore.dart';

enum VendorSupportSender { vendor, staff }

/// One message in `vendor_support_threads/{vendorId}/messages`.
class VendorSupportMessage {
  const VendorSupportMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final VendorSupportSender sender;
  final String text;
  final DateTime? createdAt;

  factory VendorSupportMessage.fromFirestore(String id, Map<String, dynamic> data) {
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    return VendorSupportMessage(
      id: id,
      sender: (data['senderType'] as String?)?.trim() == 'staff'
          ? VendorSupportSender.staff
          : VendorSupportSender.vendor,
      text: (data['text'] as String?)?.trim() ?? '',
      createdAt: ts?.toDate(),
    );
  }
}
