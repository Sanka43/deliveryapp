import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/core/utils/product_option_labels.dart';

void main() {
  group('parseTypeSizeComboLabel', () {
    test('splits Type · Size', () {
      final combo = parseTypeSizeComboLabel('Chicken · Full');
      expect(combo, isNotNull);
      expect(combo!.type, 'Chicken');
      expect(combo.size, 'Full');
    });

    test('returns null when there is no separator', () {
      expect(parseTypeSizeComboLabel('Batu Moju'), isNull);
    });
  });

  group('buildProductTypeGroups', () {
    test('groups Type · Size combos by type, sizes in first-seen order', () {
      final groups = buildProductTypeGroups(const <String>[
        'Chicken · Full',
        'Chicken · Half',
        'Beef · Half',
        'Beef · Full',
      ]);
      expect(groups.map((g) => g.type), <String>['Chicken', 'Beef']);

      final chicken = groups[0];
      expect(chicken.hasSizeChoice, isTrue);
      expect(chicken.sizes.map((s) => s.size), <String>['Full', 'Half']);
      expect(chicken.sizes.map((s) => s.optionIndex), <int>[0, 1]);

      final beef = groups[1];
      expect(beef.sizes.map((s) => s.size), <String>['Half', 'Full']);
      expect(beef.sizes.map((s) => s.optionIndex), <int>[2, 3]);
    });

    test('treats a name without · as its own type with one implicit size', () {
      final groups = buildProductTypeGroups(const <String>['Batu Moju']);
      expect(groups, hasLength(1));
      expect(groups.single.type, 'Batu Moju');
      expect(groups.single.hasSizeChoice, isFalse);
      expect(groups.single.sizes.single.size, '');
      expect(groups.single.sizes.single.optionIndex, 0);
    });

    test('mixes Type · Size combos with standalone items', () {
      // e.g. a curry item where "Chicken · Large" is a real type+size combo
      // but "Batu Moju" is just a standalone side sold on its own.
      final groups = buildProductTypeGroups(const <String>[
        'Chicken · Large',
        'Beef · Medium',
        'Beef · Large',
        'Batu Moju',
      ]);
      expect(groups.map((g) => g.type), <String>['Chicken', 'Beef', 'Batu Moju']);
      expect(groups[0].hasSizeChoice, isFalse);
      expect(groups[1].hasSizeChoice, isTrue);
      expect(groups[1].sizes.map((s) => s.size), <String>['Medium', 'Large']);
      expect(groups[2].hasSizeChoice, isFalse);
      expect(groups[2].sizes.single.size, '');
    });
  });
}
