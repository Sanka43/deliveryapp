/// Android notification channel identifiers for rider push.
abstract final class RiderPushChannels {
  static const String defaultChannelId = 'mnd_rider_default';
  static const String defaultChannelName = 'MND Rider';
  static const String defaultChannelDescription =
      'Delivery requests, order updates, and earnings';

  static const String offersChannelId = 'mnd_rider_offers';
  static const String offersChannelName = 'Delivery offers';
  static const String offersChannelDescription = 'New delivery job alerts';

  static const String earningsChannelId = 'mnd_rider_earnings';
  static const String earningsChannelName = 'Earnings';
  static const String earningsChannelDescription = 'Payout and earnings updates';
}
