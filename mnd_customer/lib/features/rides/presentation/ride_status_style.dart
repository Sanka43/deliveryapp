import 'package:mnd_delivery_app/core/widgets/home/mnd_gradient_badge.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';

/// Display labels + badge styles for ride trip statuses.
class RideStatusStyle {
  RideStatusStyle._();

  static String labelFor(String status) {
    return switch (status) {
      RideConstants.statusDraftPayment => 'Awaiting payment',
      RideConstants.statusSearching => 'Finding driver',
      RideConstants.statusAccepted => 'Driver assigned',
      RideConstants.statusArrived => 'Driver arrived',
      RideConstants.statusInProgress => 'On the way',
      RideConstants.statusCompleted => 'Completed',
      RideConstants.statusCancelled => 'Cancelled',
      _ => status.isEmpty ? 'Unknown' : status,
    };
  }

  static MndBadgeStyle badgeStyleFor(String status) {
    return switch (status) {
      RideConstants.statusCompleted => MndBadgeStyle.success,
      RideConstants.statusCancelled => MndBadgeStyle.error,
      RideConstants.statusSearching ||
      RideConstants.statusDraftPayment =>
        MndBadgeStyle.warning,
      RideConstants.statusAccepted ||
      RideConstants.statusArrived ||
      RideConstants.statusInProgress =>
        MndBadgeStyle.brand,
      _ => MndBadgeStyle.neutral,
    };
  }
}
