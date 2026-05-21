import 'package:equatable/equatable.dart';

/// Local notification preferences, synced to FCM topic subscription.
class AppNotificationSettings extends Equatable {
  const AppNotificationSettings({
    required this.orderUpdates,
    required this.promotions,
  });

  final bool orderUpdates;
  final bool promotions;

  AppNotificationSettings copyWith({
    bool? orderUpdates,
    bool? promotions,
  }) {
    return AppNotificationSettings(
      orderUpdates: orderUpdates ?? this.orderUpdates,
      promotions: promotions ?? this.promotions,
    );
  }

  @override
  List<Object?> get props => <Object?>[orderUpdates, promotions];
}
