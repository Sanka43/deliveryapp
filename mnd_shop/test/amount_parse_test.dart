import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/features/create_order/domain/amount_parse.dart';

void main() {
  group('parseAmountInput', () {
    test('parses 1.5 kg', () {
      final AmountParseResult? r = parseAmountInput('1.5 kg');
      expect(r, isNotNull);
      expect(r!.quantity, 1.5);
      expect(r.amountLabel, '1.5 kg');
      expect(r.unitSuffix, 'kg');
    });

    test('rejects unit-only and empty', () {
      expect(parseAmountInput('kg'), isNull);
      expect(parseAmountInput(''), isNull);
    });

    test('260 × 1.5 rounds to 390', () {
      expect((260 * 1.5).round(), 390);
    });
  });
}
