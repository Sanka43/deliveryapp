/// Parses free-text amounts like `1.5 kg` for vendor create-order.
class AmountParseResult {
  const AmountParseResult({
    required this.quantity,
    required this.amountLabel,
    required this.unitSuffix,
  });

  final double quantity;
  final String amountLabel;
  final String unitSuffix;
}

final RegExp _amountPattern = RegExp(
  r'^(\d+(?:\.\d{1,2})?)\s*(.*)$',
);

/// Returns null when input is empty/invalid or qty is out of range.
AmountParseResult? parseAmountInput(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final Match? m = _amountPattern.firstMatch(trimmed);
  if (m == null) {
    return null;
  }
  final double? qty = double.tryParse(m.group(1)!);
  if (qty == null || qty <= 0 || qty > 999) {
    return null;
  }
  // Enforce max 2 decimal places via pattern; normalize label.
  final String unit = (m.group(2) ?? '').trim();
  final String qtyText = _formatQty(qty);
  final String label =
      unit.isEmpty ? qtyText : '$qtyText $unit'.trim();
  return AmountParseResult(
    quantity: qty,
    amountLabel: label.length > 80 ? label.substring(0, 80) : label,
    unitSuffix: unit,
  );
}

String formatAmountLabel({
  required double quantity,
  required String unitSuffix,
}) {
  final String qtyText = _formatQty(quantity);
  final String unit = unitSuffix.trim();
  final String label = unit.isEmpty ? qtyText : '$qtyText $unit';
  return label.length > 80 ? label.substring(0, 80) : label;
}

String unitSuffixFromAmountLabel(String amountLabel) {
  final AmountParseResult? parsed = parseAmountInput(amountLabel);
  return parsed?.unitSuffix ?? '';
}

String _formatQty(double qty) {
  if (qty == qty.roundToDouble()) {
    return qty.round().toString();
  }
  // Trim trailing zeros up to 2 decimals.
  final String s = qty.toStringAsFixed(2);
  if (s.endsWith('0') && s.contains('.')) {
    final String one = qty.toStringAsFixed(1);
    if (double.parse(one) == qty) {
      return one;
    }
  }
  return s;
}
