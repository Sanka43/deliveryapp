import 'package:cloud_firestore/cloud_firestore.dart';

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.line1,
    required this.line2,
    required this.city,
    required this.phone,
    required this.isDefault,
    this.createdAt,
  });

  final String id;
  final String label;
  final String line1;
  final String line2;
  final String city;
  final String phone;
  final bool isDefault;
  final DateTime? createdAt;

  factory SavedAddress.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    return SavedAddress(
      id: doc.id,
      label: (data['label'] as String?)?.trim().isNotEmpty == true
          ? data['label'] as String
          : 'Address',
      line1: (data['line1'] as String?) ?? '',
      line2: (data['line2'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      isDefault: data['isDefault'] as bool? ?? false,
      createdAt: ts?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore({bool includeCreatedAt = false}) {
    return <String, dynamic>{
      'label': label.trim(),
      'line1': line1.trim(),
      'line2': line2.trim(),
      'city': city.trim(),
      'phone': phone.trim(),
      'isDefault': isDefault,
      if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
