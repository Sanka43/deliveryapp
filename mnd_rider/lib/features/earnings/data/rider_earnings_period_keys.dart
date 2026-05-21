import 'package:intl/intl.dart';

/// Firestore aggregate document keys and date helpers.
abstract final class RiderEarningsPeriodKeys {
  static String dailyKey(DateTime date) {
    final DateTime d = DateTime(date.year, date.month, date.day);
    return 'daily_${DateFormat('yyyy-MM-dd').format(d)}';
  }

  static String weeklyKey(DateTime date) {
    final DateTime start = startOfWeek(date);
    final int week = _isoWeekNumber(start);
    return 'weekly_${start.year}-W${week.toString().padLeft(2, '0')}';
  }

  static String monthlyKey(DateTime date) {
    return 'monthly_${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime startOfWeek(DateTime date) {
    final DateTime day = startOfDay(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month);

  static int _isoWeekNumber(DateTime date) {
    final int dayOfYear = int.parse(DateFormat('D').format(date));
    final int weekDay = date.weekday;
    return ((dayOfYear - weekDay + 10) / 7).floor();
  }
}
