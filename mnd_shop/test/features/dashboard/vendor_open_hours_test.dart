import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_open_hours.dart';

DateTime atColombo(int year, int month, int day, int hour, int minute) {
  // Same construction as domain helper: wall clock as UTC label, then −05:30.
  return DateTime.utc(year, month, day, hour, minute).subtract(kColomboOffset);
}

void main() {
  const OpeningHours weekdayHours = OpeningHours(
    defaultOpen: '09:00',
    defaultClose: '21:00',
    closedSunday: true,
  );

  const OpeningHours overnightHours = OpeningHours(
    defaultOpen: '22:00',
    defaultClose: '02:00',
    closedSunday: true,
  );

  group('vendor_open_hours', () {
    test('desiredActive inside weekday window', () {
      expect(desiredActive(atColombo(2026, 7, 31, 10, 0), weekdayHours), isTrue);
    });

    test('desiredActive outside weekday window', () {
      expect(desiredActive(atColombo(2026, 7, 31, 8, 59), weekdayHours), isFalse);
      expect(desiredActive(atColombo(2026, 7, 31, 21, 0), weekdayHours), isFalse);
    });

    test('desiredActive closed Sunday', () {
      expect(desiredActive(atColombo(2026, 8, 2, 12, 0), weekdayHours), isFalse);
    });

    test('desiredActive overnight and Sunday cut-off', () {
      expect(desiredActive(atColombo(2026, 8, 1, 23, 0), overnightHours), isTrue);
      expect(desiredActive(atColombo(2026, 8, 2, 1, 0), overnightHours), isFalse);
      expect(desiredActive(atColombo(2026, 7, 31, 23, 30), overnightHours), isTrue);
      expect(desiredActive(atColombo(2026, 8, 1, 1, 30), overnightHours), isTrue);
    });

    test('nextScheduleBoundary next close while open', () {
      final DateTime next =
          nextScheduleBoundary(atColombo(2026, 7, 31, 10, 0), weekdayHours);
      expect(next, atColombo(2026, 7, 31, 21, 0));
    });

    test('nextScheduleBoundary skips Sunday to Monday open', () {
      final DateTime next =
          nextScheduleBoundary(atColombo(2026, 8, 2, 12, 0), weekdayHours);
      expect(next, atColombo(2026, 8, 3, 9, 0));
    });

    test('sync holds override then applies schedule after expiry', () {
      final SyncVendorOpenResult held = syncVendorOpenStatus(
        now: atColombo(2026, 7, 31, 10, 0),
        approvalStatus: 'approved',
        active: false,
        openingHours: <String, dynamic>{
          'defaultOpen': '09:00',
          'defaultClose': '21:00',
          'closedSunday': true,
        },
        openOverrideUntil: atColombo(2026, 7, 31, 21, 0),
      );
      expect(held.skippedDueToOverride, isTrue);
      expect(held.changed, isFalse);
      expect(held.active, isFalse);

      final SyncVendorOpenResult after = syncVendorOpenStatus(
        now: atColombo(2026, 7, 31, 10, 0),
        approvalStatus: 'approved',
        active: false,
        openingHours: <String, dynamic>{
          'defaultOpen': '09:00',
          'defaultClose': '21:00',
          'closedSunday': true,
        },
        openOverrideUntil: atColombo(2026, 7, 31, 9, 0),
      );
      expect(after.active, isTrue);
      expect(after.clearOverride, isTrue);
      expect(after.changed, isTrue);
    });

    test('subtitle kinds for auto and manual', () {
      final VendorOpenSubtitle auto = vendorOpenStatusSubtitle(
        isOpen: true,
        now: atColombo(2026, 7, 31, 10, 0),
        openingHours: <String, dynamic>{
          'defaultOpen': '09:00',
          'defaultClose': '21:00',
          'closedSunday': true,
        },
        openOverrideUntil: null,
        canToggle: true,
      );
      expect(auto.kind, VendorOpenSubtitleKind.autoOpenUntil);

      final VendorOpenSubtitle manual = vendorOpenStatusSubtitle(
        isOpen: false,
        now: atColombo(2026, 7, 31, 10, 0),
        openingHours: <String, dynamic>{
          'defaultOpen': '09:00',
          'defaultClose': '21:00',
          'closedSunday': true,
        },
        openOverrideUntil: atColombo(2026, 7, 31, 21, 0),
        canToggle: true,
      );
      expect(manual.kind, VendorOpenSubtitleKind.manualClosedUntil);
    });
  });
}
