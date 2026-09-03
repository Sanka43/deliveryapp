/// Shared LKR money formatting for cart, checkout, orders, and bars.
class MoneyFormat {
  MoneyFormat._();

  /// Groups thousands with commas, e.g. `LKR 1,234.00`.
  static String lkr(int amount, {bool signed = false, bool showDecimals = true}) {
    final String grouped = _groupThousands(amount.abs());
    final String body = showDecimals ? '$grouped.00' : grouped;
    if (!signed) {
      return 'LKR $body';
    }
    final String sign = amount < 0 ? '-' : '+';
    return '$sign LKR $body';
  }

  static String _groupThousands(int n) {
    final String s = n.toString();
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        b.write(',');
      }
      b.write(s[i]);
    }
    return b.toString();
  }
}
