/// Product price strings for customer UI (Rs instead of LKR).
class ProductPriceDisplay {
  ProductPriceDisplay._();

  /// Numeric amount only, whole rupees, no decimals (e.g. `800`).
  static String formatAmount(int amountLkr) {
    return amountLkr.toString();
  }

  /// Parses digits from a raw price fragment and formats as `800`.
  static String formatAmountFromRaw(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '0';
    }
    final String normalized = trimmed.replaceAll(',', '');
    final double? value = double.tryParse(
      normalized.replaceAll(RegExp(r'[^\d.]'), ''),
    );
    if (value == null) {
      return '0';
    }
    return value.round().toString();
  }

  static String format(int amount, {bool from = false}) {
    final String body = 'Rs ${formatAmount(amount)}';
    return from ? 'From $body' : body;
  }

  /// Converts legacy `LKR` labels and collapses extra spaces.
  static String normalize(String raw) {
    final ProductPriceParts parts = parse(raw);
    final String prefix = parts.showFrom ? 'From Rs ' : 'Rs ';
    return '$prefix${parts.amount}';
  }

  /// Splits a normalized price into a small prefix (`From Rs` / `Rs`) and amount.
  static ProductPriceParts parse(String raw) {
    final String stripped = raw
        .trim()
        .replaceAll(RegExp(r'\bLKR\b', caseSensitive: false), 'Rs')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    if (stripped.isEmpty) {
      return const ProductPriceParts(amount: '0');
    }

    final RegExp fromPattern = RegExp(
      r'^From\s+Rs\.?\s*(.+)$',
      caseSensitive: false,
    );
    final Match? fromMatch = fromPattern.firstMatch(stripped);
    if (fromMatch != null) {
      return ProductPriceParts(
        showFrom: true,
        amount: formatAmountFromRaw(fromMatch.group(1)!),
      );
    }

    final RegExp rsPattern = RegExp(
      r'^Rs\.?\s*(.+)$',
      caseSensitive: false,
    );
    final Match? rsMatch = rsPattern.firstMatch(stripped);
    if (rsMatch != null) {
      return ProductPriceParts(
        amount: formatAmountFromRaw(rsMatch.group(1)!),
      );
    }

    return ProductPriceParts(amount: formatAmountFromRaw(stripped));
  }
}

class ProductPriceParts {
  const ProductPriceParts({
    required this.amount,
    this.showFrom = false,
  });

  final bool showFrom;
  final String amount;
}
