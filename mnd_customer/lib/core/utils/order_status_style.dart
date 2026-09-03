import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_gradient_badge.dart';

/// Maps order status strings to conventional colors / badge styles.
class OrderStatusStyle {
  OrderStatusStyle._();

  static Color colorFor(String statusRaw) {
    final String key = statusRaw.toLowerCase().trim();
    switch (key) {
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'out_for_delivery':
      case 'on_the_way':
        return AppColors.brandPrimary;
      case 'draft_payment':
      case 'preparing':
      case 'ready':
      case 'confirmed':
        return AppColors.warning;
      case 'placed':
      default:
        return AppColors.brandPrimary;
    }
  }

  static MndBadgeStyle badgeStyleFor(String statusRaw) {
    final String key = statusRaw.toLowerCase().trim();
    switch (key) {
      case 'delivered':
        return MndBadgeStyle.success;
      case 'cancelled':
        return MndBadgeStyle.error;
      case 'out_for_delivery':
      case 'on_the_way':
        return MndBadgeStyle.brand;
      case 'draft_payment':
      case 'preparing':
      case 'ready':
      case 'confirmed':
        return MndBadgeStyle.warning;
      default:
        return MndBadgeStyle.brand;
    }
  }

  static bool isTrackable(String statusRaw, {required String? riderId}) {
    final String key = statusRaw.toLowerCase().trim();
    if (key == 'delivered' || key == 'cancelled') {
      return false;
    }
    final String? id = riderId?.trim();
    return id != null && id.isNotEmpty &&
        (key == 'out_for_delivery' ||
            key == 'on_the_way' ||
            key == 'ready' ||
            key == 'preparing');
  }
}
