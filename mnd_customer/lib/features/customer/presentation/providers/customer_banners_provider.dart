import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';

class CustomerBanner {
  const CustomerBanner({
    required this.title,
    required this.subtitle,
    required this.startColor,
    required this.endColor,
    required this.iconKey,
    required this.order,
    this.imageUrl,
    this.endsAt,
    this.targetRoute,
    this.targetStoreId,
    this.targetQuery,
  });

  final String title;
  final String subtitle;
  final Color startColor;
  final Color endColor;
  final String iconKey;
  final int order;
  final String? imageUrl;
  final DateTime? endsAt;
  /// Optional deep link path (e.g. `/customer/food`) or named key `food`/`grocery`/`rides`/`jobs`.
  final String? targetRoute;
  final String? targetStoreId;
  final String? targetQuery;

  factory CustomerBanner.fromMap(Map<String, dynamic> map) {
    DateTime? endsAt;
    final dynamic endsRaw = map['endsAt'];
    if (endsRaw is Timestamp) {
      endsAt = endsRaw.toDate();
    } else if (endsRaw is DateTime) {
      endsAt = endsRaw;
    }

    return CustomerBanner(
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? map['title'] as String
          : 'Special Offer',
      subtitle: (map['subtitle'] as String?)?.trim().isNotEmpty == true
          ? map['subtitle'] as String
          : 'Limited-time deals',
      startColor: _parseColor(map['startColor']) ?? const Color(0xFF2563EB),
      endColor: _parseColor(map['endColor']) ?? const Color(0xFF1D4ED8),
      iconKey: (map['iconKey'] as String?)?.trim().isNotEmpty == true
          ? map['iconKey'] as String
          : 'delivery',
      order: (map['order'] as num?)?.toInt() ?? 999,
      imageUrl: (map['imageUrl'] as String?)?.trim().isNotEmpty == true
          ? map['imageUrl'] as String
          : null,
      endsAt: endsAt,
      targetRoute: (map['targetRoute'] as String?)?.trim().isNotEmpty == true
          ? (map['targetRoute'] as String).trim()
          : ((map['link'] as String?)?.trim().isNotEmpty == true
              ? (map['link'] as String).trim()
              : null),
      targetStoreId: (map['targetStoreId'] as String?)?.trim().isNotEmpty == true
          ? (map['targetStoreId'] as String).trim()
          : ((map['storeId'] as String?)?.trim().isNotEmpty == true
              ? (map['storeId'] as String).trim()
              : null),
      targetQuery: (map['targetQuery'] as String?)?.trim().isNotEmpty == true
          ? (map['targetQuery'] as String).trim()
          : null,
    );
  }

  static Color? _parseColor(dynamic value) {
    if (value is int) {
      return Color(value);
    }
    if (value is String) {
      final String hex = value.replaceAll('#', '').trim();
      if (hex.isEmpty) {
        return null;
      }
      final int? colorValue = int.tryParse('FF$hex', radix: 16);
      if (colorValue == null) {
        return null;
      }
      return Color(colorValue);
    }
    return null;
  }
}

final StreamProvider<List<CustomerBanner>> customerBannersProvider =
    StreamProvider<List<CustomerBanner>>((Ref ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirebaseCollections.banners)
      .where('active', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
    final List<CustomerBanner> banners = snapshot.docs
        .map((doc) => CustomerBanner.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return banners;
  });
});
