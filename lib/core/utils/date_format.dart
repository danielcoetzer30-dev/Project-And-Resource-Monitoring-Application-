/// Date formatting used across the app.
///
/// Gathered here because the Seam axis and the mock repository had grown their
/// own copies of the same month table, which is exactly how two parts of one
/// screen end up disagreeing about what day it is.
abstract final class DateFormatting {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "12 Sep" — for Seam axes and compact rows.
  static String shortDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  /// "12 Sep 2026" — where the year matters.
  static String mediumDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  /// "14:05" — 24-hour, which is how outage windows are published.
  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  /// "12 Sep, 14:05"
  static String dateAndTime(DateTime date) =>
      '${shortDate(date)}, ${time(date)}';
}
