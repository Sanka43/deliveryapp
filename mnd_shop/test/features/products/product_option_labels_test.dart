import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/features/products/domain/product_option_labels.dart';

void main() {
  group('parseTypeSizeComboLabel', () {
    test('parses Type · Size', () {
      final parsed = parseTypeSizeComboLabel('Chicken · Full');
      expect(parsed?.type, 'Chicken');
      expect(parsed?.size, 'Full');
    });

    test('rejects unknown size segment', () {
      expect(parseTypeSizeComboLabel('Chicken · XL'), isNull);
    });

    test('rejects flat half label', () {
      expect(parseTypeSizeComboLabel('Half'), isNull);
    });
  });

  group('labelLooksLikePresetOption', () {
    test('accepts type matrix labels', () {
      expect(labelLooksLikePresetOption('Beef · Half'), isTrue);
    });

    test('accepts plain half', () {
      expect(labelLooksLikePresetOption('Full'), isTrue);
    });
  });

  test('typeSizeComboLabel joins with middle dot', () {
    expect(typeSizeComboLabel(type: 'Egg', size: 'Half'), 'Egg · Half');
  });

  group('custom food types memory', () {
    test('extracts non-preset types from option names', () {
      expect(
        customFoodTypesFromOptionNames(const <String>[
          'Chicken · Full',
          'Mutton · Half',
          'Mutton · Full',
          'Half',
        ]),
        <String>['Mutton'],
      );
    });

    test('parseCustomFoodTypesField drops presets', () {
      expect(
        parseCustomFoodTypesField(<dynamic>['Mutton', 'chicken', '  ', 'Fish']),
        <String>['Mutton'],
      );
    });

    test('mergeCustomFoodTypeLists keeps first spelling', () {
      expect(
        mergeCustomFoodTypeLists(<Iterable<String>>[
          <String>['Mutton'],
          <String>['mutton', 'Prawns'],
        ]),
        <String>['Mutton', 'Prawns'],
      );
    });
  });
}
