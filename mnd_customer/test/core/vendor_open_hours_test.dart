import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/core/utils/vendor_open_hours.dart';

void main() {
  group('VendorOpeningHours.fromVendorDoc', () {
    test('falls back to 09:00-21:00 when openingHours is missing', () {
      final VendorOpeningHours hours = VendorOpeningHours.fromVendorDoc(null);
      expect(hours.openHour, 9);
      expect(hours.openMinute, 0);
      expect(hours.closeHour, 21);
      expect(hours.closeMinute, 0);
      expect(hours.closedSunday, isFalse);
    });

    test('reads defaultOpen/defaultClose/closedSunday from the vendor doc', () {
      final VendorOpeningHours hours = VendorOpeningHours.fromVendorDoc(
        <String, dynamic>{
          'openingHours': <String, dynamic>{
            'defaultOpen': '08:30',
            'defaultClose': '22:15',
            'closedSunday': true,
          },
        },
      );
      expect(hours.openHour, 8);
      expect(hours.openMinute, 30);
      expect(hours.closeHour, 22);
      expect(hours.closeMinute, 15);
      expect(hours.closedSunday, isTrue);
    });
  });

  group('VendorOpeningHours.isOpenAt', () {
    const VendorOpeningHours weekdayHours = VendorOpeningHours(
      openHour: 9,
      openMinute: 0,
      closeHour: 21,
      closeMinute: 0,
      closedSunday: true,
    );

    test('true inside the daily window', () {
      // Monday 2026-01-05, 10:00.
      expect(weekdayHours.isOpenAt(DateTime(2026, 1, 5, 10)), isTrue);
    });

    test('false before open and after close', () {
      expect(weekdayHours.isOpenAt(DateTime(2026, 1, 5, 8, 59)), isFalse);
      expect(weekdayHours.isOpenAt(DateTime(2026, 1, 5, 21)), isFalse);
    });

    test('false all day Sunday when closedSunday', () {
      // 2026-01-04 is a Sunday.
      expect(weekdayHours.isOpenAt(DateTime(2026, 1, 4, 12)), isFalse);
    });

    test('handles an overnight window', () {
      const VendorOpeningHours overnight = VendorOpeningHours(
        openHour: 22,
        openMinute: 0,
        closeHour: 2,
        closeMinute: 0,
        closedSunday: false,
      );
      expect(overnight.isOpenAt(DateTime(2026, 1, 5, 23)), isTrue);
      expect(overnight.isOpenAt(DateTime(2026, 1, 6, 1)), isTrue);
      expect(overnight.isOpenAt(DateTime(2026, 1, 6, 12)), isFalse);
    });
  });
}
