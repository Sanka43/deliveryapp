import 'package:cloud_firestore/cloud_firestore.dart';

/// Platform monthly fee invoice under `vendors/{vendorId}/monthly_invoices/{yyyy-MM}`.
class VendorMonthlyInvoice {
  const VendorMonthlyInvoice({
    required this.id,
    required this.monthKey,
    required this.netSalesLkr,
    required this.feePercent,
    required this.feeLkr,
    required this.status,
    this.notes = '',
    this.invoicedAt,
    this.paidAt,
  });

  final String id;
  final String monthKey;
  final double netSalesLkr;
  final double feePercent;
  final double feeLkr;

  /// `pending` | `invoiced` | `paid`
  final String status;
  final String notes;
  final DateTime? invoicedAt;
  final DateTime? paidAt;

  bool get isPending => status == 'pending';
  bool get isInvoiced => status == 'invoiced';
  bool get isPaid => status == 'paid';

  factory VendorMonthlyInvoice.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return VendorMonthlyInvoice(
      id: id,
      monthKey: (data['monthKey'] as String?)?.trim().isNotEmpty == true
          ? (data['monthKey'] as String).trim()
          : id,
      netSalesLkr: _readDouble(data['netSalesLkr']),
      feePercent: _readDouble(data['feePercent']),
      feeLkr: _readDouble(data['feeLkr']),
      status: ((data['status'] as String?)?.trim().toLowerCase().isNotEmpty ==
              true)
          ? (data['status'] as String).trim().toLowerCase()
          : 'pending',
      notes: (data['notes'] as String?)?.trim() ?? '',
      invoicedAt: _readDate(data['invoicedAt']),
      paidAt: _readDate(data['paidAt']),
    );
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
