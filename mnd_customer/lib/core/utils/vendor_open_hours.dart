/// Mirrors `parseOpeningHours`/`desiredActive` in
/// `functions/src/vendorOpenHours.ts` — client-side only, used to warn (not
/// block) when a customer schedules a checkout order outside a vendor's
/// usual hours. The server doesn't re-validate this; it's guidance only.
///
/// Like the rest of this app, times are treated as plain Sri Lanka wall-clock
/// values with no timezone conversion — the vendor's `defaultOpen`/
/// `defaultClose` strings and the customer's picked date/time both already
/// mean "Colombo local time".
class VendorOpeningHours {
  const VendorOpeningHours({
    required this.openHour,
    required this.openMinute,
    required this.closeHour,
    required this.closeMinute,
    required this.closedSunday,
  });

  final int openHour;
  final int openMinute;
  final int closeHour;
  final int closeMinute;
  final bool closedSunday;

  /// Falls back to 09:00–21:00 (not closed Sunday) when the vendor doc has
  /// no `openingHours`, matching the Cloud Functions default.
  factory VendorOpeningHours.fromVendorDoc(Map<String, dynamic>? vendor) {
    return VendorOpeningHours.fromRaw(
      vendor?['openingHours'] as Map<String, dynamic>?,
    );
  }

  /// Same as [VendorOpeningHours.fromVendorDoc], but given the
  /// `openingHours` map directly rather than the whole vendor doc.
  factory VendorOpeningHours.fromRaw(Map<String, dynamic>? raw) {
    final List<int> open =
        _parseHm(raw?['defaultOpen'] as String?) ?? const <int>[9, 0];
    final List<int> close =
        _parseHm(raw?['defaultClose'] as String?) ?? const <int>[21, 0];
    return VendorOpeningHours(
      openHour: open[0],
      openMinute: open[1],
      closeHour: close[0],
      closeMinute: close[1],
      closedSunday: raw?['closedSunday'] == true,
    );
  }

  /// Whether [candidate]'s wall-clock hour/minute/weekday falls inside these
  /// hours. Handles an overnight window (e.g. 22:00 → 02:00).
  bool isOpenAt(DateTime candidate) {
    if (closedSunday && candidate.weekday == DateTime.sunday) {
      return false;
    }
    final int nowMin = candidate.hour * 60 + candidate.minute;
    final int openMin = openHour * 60 + openMinute;
    final int closeMin = closeHour * 60 + closeMinute;
    if (openMin < closeMin) {
      return nowMin >= openMin && nowMin < closeMin;
    }
    return nowMin >= openMin || nowMin < closeMin;
  }
}

/// Parses "H:mm" / "HH:mm" into `[hour, minute]`, or null if malformed —
/// mirrors `parseHm` in `functions/src/vendorOpenHours.ts`.
List<int>? _parseHm(String? raw) {
  if (raw == null) {
    return null;
  }
  final RegExpMatch? m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
  if (m == null) {
    return null;
  }
  final int hour = int.parse(m.group(1)!);
  final int minute = int.parse(m.group(2)!);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return <int>[hour, minute];
}
