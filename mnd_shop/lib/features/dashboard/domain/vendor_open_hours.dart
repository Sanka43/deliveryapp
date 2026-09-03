/// Asia/Colombo (+05:30, no DST) opening-hours helpers for vendor auto open/close.
///
/// Mirrors `functions/src/vendorOpenHours.ts`.
library;

const Duration kColomboOffset = Duration(hours: 5, minutes: 30);

class OpeningHours {
  const OpeningHours({
    required this.defaultOpen,
    required this.defaultClose,
    required this.closedSunday,
  });

  final String defaultOpen;
  final String defaultClose;
  final bool closedSunday;

  static const OpeningHours defaults = OpeningHours(
    defaultOpen: '09:00',
    defaultClose: '21:00',
    closedSunday: false,
  );
}

class _Hm {
  const _Hm(this.hour, this.minute);
  final int hour;
  final int minute;
}

class _ColomboParts {
  const _ColomboParts({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.dayOfWeek,
  });

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;

  /// `DateTime.sunday` == 7 in Dart; we store 0=Sunday … 6=Saturday.
  final int dayOfWeek;
}

_ColomboParts _toColomboParts(DateTime utc) {
  final DateTime u = utc.toUtc();
  final DateTime local = u.add(kColomboOffset);
  // Treat [local] wall components as Colombo; weekday: Dart Mon=1…Sun=7 → 0=Sun.
  final int dow = local.weekday % 7;
  return _ColomboParts(
    year: local.year,
    month: local.month,
    day: local.day,
    hour: local.hour,
    minute: local.minute,
    dayOfWeek: dow,
  );
}

DateTime _colomboDateTimeToUtc(
  int year,
  int month,
  int day,
  int hour,
  int minute,
) {
  // Interpret wall clock as Colombo, convert to UTC.
  final DateTime asUtcLabel = DateTime.utc(year, month, day, hour, minute);
  return asUtcLabel.subtract(kColomboOffset);
}

_Hm? _parseHm(String? raw) {
  if (raw == null) {
    return null;
  }
  final Match? m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
  if (m == null) {
    return null;
  }
  final int hour = int.parse(m.group(1)!);
  final int minute = int.parse(m.group(2)!);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return _Hm(hour, minute);
}

OpeningHours parseOpeningHours(Object? raw) {
  if (raw is! Map) {
    return OpeningHours.defaults;
  }
  final Map<dynamic, dynamic> map = raw;
  final String openRaw = (map['defaultOpen'] as String?)?.trim() ?? '';
  final String closeRaw = (map['defaultClose'] as String?)?.trim() ?? '';
  return OpeningHours(
    defaultOpen: _parseHm(openRaw) != null ? openRaw : OpeningHours.defaults.defaultOpen,
    defaultClose:
        _parseHm(closeRaw) != null ? closeRaw : OpeningHours.defaults.defaultClose,
    closedSunday: map['closedSunday'] == true,
  );
}

int _minutesOfDay(int hour, int minute) => hour * 60 + minute;

_ColomboParts _addCalendarDays(_ColomboParts parts, int days) {
  final DateTime noon = _colomboDateTimeToUtc(
    parts.year,
    parts.month,
    parts.day,
    12,
    0,
  );
  return _toColomboParts(noon.add(Duration(days: days)));
}

/// Whether the shop should accept orders at [now] (Asia/Colombo).
bool desiredActive(DateTime now, OpeningHours hours) {
  final _ColomboParts parts = _toColomboParts(now.toUtc());
  if (hours.closedSunday && parts.dayOfWeek == 0) {
    return false;
  }
  final _Hm open = _parseHm(hours.defaultOpen) ?? const _Hm(9, 0);
  final _Hm close = _parseHm(hours.defaultClose) ?? const _Hm(21, 0);
  final int nowMin = _minutesOfDay(parts.hour, parts.minute);
  final int openMin = _minutesOfDay(open.hour, open.minute);
  final int closeMin = _minutesOfDay(close.hour, close.minute);
  if (openMin < closeMin) {
    return nowMin >= openMin && nowMin < closeMin;
  }
  return nowMin >= openMin || nowMin < closeMin;
}

/// Next open or close instant after [now] (Asia/Colombo).
DateTime nextScheduleBoundary(DateTime now, OpeningHours hours) {
  final _Hm open = _parseHm(hours.defaultOpen) ?? const _Hm(9, 0);
  final _Hm close = _parseHm(hours.defaultClose) ?? const _Hm(21, 0);
  final int openMin = _minutesOfDay(open.hour, open.minute);
  final int closeMin = _minutesOfDay(close.hour, close.minute);
  final bool overnight = openMin >= closeMin;
  final DateTime nowUtc = now.toUtc();
  final int nowMs = nowUtc.millisecondsSinceEpoch;
  final List<DateTime> candidates = <DateTime>[];
  final _ColomboParts start = _toColomboParts(nowUtc);

  for (int offset = 0; offset <= 8; offset++) {
    final _ColomboParts d = _addCalendarDays(start, offset);
    final bool closedDay = hours.closedSunday && d.dayOfWeek == 0;

    if (!overnight) {
      if (closedDay) {
        continue;
      }
      candidates.add(
        _colomboDateTimeToUtc(d.year, d.month, d.day, open.hour, open.minute),
      );
      candidates.add(
        _colomboDateTimeToUtc(d.year, d.month, d.day, close.hour, close.minute),
      );
      continue;
    }

    if (closedDay) {
      continue;
    }
    candidates.add(
      _colomboDateTimeToUtc(d.year, d.month, d.day, open.hour, open.minute),
    );
    final _ColomboParts next = _addCalendarDays(d, 1);
    if (hours.closedSunday && next.dayOfWeek == 0) {
      candidates.add(
        _colomboDateTimeToUtc(next.year, next.month, next.day, 0, 0),
      );
    } else {
      candidates.add(
        _colomboDateTimeToUtc(
          next.year,
          next.month,
          next.day,
          close.hour,
          close.minute,
        ),
      );
    }
  }

  candidates.sort(
    (DateTime a, DateTime b) => a.millisecondsSinceEpoch.compareTo(b.millisecondsSinceEpoch),
  );
  for (final DateTime c in candidates) {
    if (c.millisecondsSinceEpoch > nowMs) {
      return c;
    }
  }
  return nowUtc.add(const Duration(days: 1));
}

bool isApprovalBlocking(String? approvalStatus) {
  return approvalStatus == 'pending' || approvalStatus == 'rejected';
}

class SyncVendorOpenResult {
  const SyncVendorOpenResult({
    required this.active,
    required this.clearOverride,
    required this.changed,
    required this.skippedDueToOverride,
  });

  final bool active;
  final bool clearOverride;
  final bool changed;
  final bool skippedDueToOverride;
}

SyncVendorOpenResult syncVendorOpenStatus({
  required DateTime now,
  required String? approvalStatus,
  required bool? active,
  required Object? openingHours,
  required DateTime? openOverrideUntil,
}) {
  if (isApprovalBlocking(approvalStatus)) {
    return SyncVendorOpenResult(
      active: false,
      clearOverride: openOverrideUntil != null,
      changed: active != false || openOverrideUntil != null,
      skippedDueToOverride: false,
    );
  }

  if (openOverrideUntil != null &&
      now.toUtc().isBefore(openOverrideUntil.toUtc())) {
    return SyncVendorOpenResult(
      active: active == true,
      clearOverride: false,
      changed: false,
      skippedDueToOverride: true,
    );
  }

  final OpeningHours hours = parseOpeningHours(openingHours);
  final bool desired = desiredActive(now, hours);
  final bool hadOverride = openOverrideUntil != null;
  return SyncVendorOpenResult(
    active: desired,
    clearOverride: hadOverride,
    changed: active != desired || hadOverride,
    skippedDueToOverride: false,
  );
}

/// Human-readable time like `9:00 AM` for status subtitles.
String formatColomboClock(DateTime utcOrLocal) {
  final _ColomboParts p = _toColomboParts(utcOrLocal.toUtc());
  final int hour24 = p.hour;
  final int minute = p.minute;
  final String period = hour24 >= 12 ? 'PM' : 'AM';
  int hour12 = hour24 % 12;
  if (hour12 == 0) {
    hour12 = 12;
  }
  final String mm = minute.toString().padLeft(2, '0');
  return '$hour12:$mm $period';
}

enum VendorOpenSubtitleKind {
  awaitingApproval,
  autoOpenUntil,
  autoOpensAt,
  manualOpenUntil,
  manualClosedUntil,
}

class VendorOpenSubtitle {
  const VendorOpenSubtitle({required this.kind, this.clock = ''});

  final VendorOpenSubtitleKind kind;
  final String clock;
}

/// Structured status line under the open/close toggle (localize in UI).
VendorOpenSubtitle vendorOpenStatusSubtitle({
  required bool isOpen,
  required DateTime now,
  required Object? openingHours,
  required DateTime? openOverrideUntil,
  required bool canToggle,
}) {
  if (!canToggle) {
    return const VendorOpenSubtitle(kind: VendorOpenSubtitleKind.awaitingApproval);
  }
  final OpeningHours hours = parseOpeningHours(openingHours);
  final bool overridden = openOverrideUntil != null &&
      now.toUtc().isBefore(openOverrideUntil.toUtc());
  final DateTime until = overridden
      ? openOverrideUntil.toUtc()
      : nextScheduleBoundary(now, hours);
  final String clock = formatColomboClock(until);

  if (overridden) {
    return VendorOpenSubtitle(
      kind: isOpen
          ? VendorOpenSubtitleKind.manualOpenUntil
          : VendorOpenSubtitleKind.manualClosedUntil,
      clock: clock,
    );
  }
  return VendorOpenSubtitle(
    kind: isOpen
        ? VendorOpenSubtitleKind.autoOpenUntil
        : VendorOpenSubtitleKind.autoOpensAt,
    clock: clock,
  );
}

String localizeVendorOpenSubtitle(
  VendorOpenSubtitle subtitle, {
  required String languageCode,
}) {
  final String clock = subtitle.clock;
  final bool si = languageCode == 'si';
  switch (subtitle.kind) {
    case VendorOpenSubtitleKind.awaitingApproval:
      return si
          ? 'Admin අනුමත කළ පසු මෙය සක්‍රීය වේ'
          : 'Available after admin approves your shop';
    case VendorOpenSubtitleKind.autoOpenUntil:
      return si ? 'විවෘතයි $clock දක්වා' : 'Open until $clock';
    case VendorOpenSubtitleKind.autoOpensAt:
      return si ? 'විවෘත වන්නේ $clock' : 'Opens at $clock';
    case VendorOpenSubtitleKind.manualOpenUntil:
      return si
          ? 'අතින් විවෘතයි $clock දක්වා'
          : 'Manually open until $clock';
    case VendorOpenSubtitleKind.manualClosedUntil:
      return si
          ? 'අතින් වසා ඇත $clock දක්වා'
          : 'Manually closed until $clock';
  }
}
