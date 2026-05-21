/// LKR / Rs. display helpers for rider UI.
abstract final class LkrFormat {
  static String money(num value) => 'Rs. ${value.round()}';

  static String moneyDecimal(double value) =>
      'Rs. ${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';
}
