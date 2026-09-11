import 'package:cloud_firestore/cloud_firestore.dart';

/// A customer review under top-level `store_ratings/{orderId}` (doc id ==
/// the rated order's id). Only `status == 'visible'` docs are ever queried —
/// hidden (admin-moderated) ratings never reach the vendor app.
class VendorReview {
  const VendorReview({
    required this.id,
    required this.stars,
    required this.comment,
    required this.createdAt,
    this.vendorReply = '',
    this.vendorReplyAt,
  });

  /// Same as the rated order's id.
  final String id;
  final int stars;
  final String comment;
  final DateTime? createdAt;

  /// The shop's own public reply to this review, if any.
  final String vendorReply;
  final DateTime? vendorReplyAt;

  bool get hasVendorReply => vendorReply.isNotEmpty;

  factory VendorReview.fromFirestore(String id, Map<String, dynamic> data) {
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final Timestamp? replyTs = data['vendorReplyAt'] as Timestamp?;
    final Object? starsRaw = data['stars'];
    final int parsedStars = starsRaw is num
        ? starsRaw.round()
        : int.tryParse(starsRaw?.toString() ?? '') ?? 0;
    final int stars = parsedStars < 1 ? 0 : (parsedStars > 5 ? 5 : parsedStars);
    return VendorReview(
      id: id,
      stars: stars,
      comment: (data['comment'] as String?)?.trim() ?? '',
      createdAt: ts?.toDate(),
      vendorReply: (data['vendorReply'] as String?)?.trim() ?? '',
      vendorReplyAt: replyTs?.toDate(),
    );
  }
}

/// Aggregate rating shown on `vendors/{id}` (`rating`, `ratingCount`),
/// server-computed by the `onStoreRating*` Cloud Functions from visible
/// reviews only.
class VendorRatingSummary {
  const VendorRatingSummary({this.average = 0, this.count = 0});

  final double average;
  final int count;

  static const VendorRatingSummary zero = VendorRatingSummary();

  factory VendorRatingSummary.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) {
      return VendorRatingSummary.zero;
    }
    final Object? avgRaw = data['rating'];
    final Object? countRaw = data['ratingCount'];
    return VendorRatingSummary(
      average: avgRaw is num ? avgRaw.toDouble() : 0,
      count: countRaw is num ? countRaw.round() : 0,
    );
  }
}
