import '../../models/preferences.dart';

/// Date formatting used across the app.
///
/// Gathered here because the Seam axis and the mock repository had grown their
/// own copies of the same month table, which is exactly how two parts of one
/// screen end up disagreeing about what day it is.
///
/// The no-argument helpers ([shortDate], [mediumDate], [time], [dateAndTime])
/// follow the person's choice under Customisations. The `…As` helpers take the
/// style explicitly, which is what lets the Customisations screen preview every
/// option side by side.
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

  static DateStyle _dateStyle = DateStyle.dayMonthName;
  static TimeStyle _timeStyle = TimeStyle.h24;

  /// Called by the preferences notifier whenever the choice changes.
  static void configure({
    required DateStyle dateStyle,
    required TimeStyle timeStyle,
  }) {
    _dateStyle = dateStyle;
    _timeStyle = timeStyle;
  }

  /// "12 Sep", for Seam axes and compact rows.
  static String shortDate(DateTime date) => shortDateAs(_dateStyle, date);

  /// "12 Sep 2026", where the year matters.
  static String mediumDate(DateTime date) => mediumDateAs(_dateStyle, date);

  /// "14:05" or "2:05 pm". 24-hour by default, which is how outage windows are
  /// published.
  static String time(DateTime date) => timeAs(_timeStyle, date);

  /// "12 Sep, 14:05"
  static String dateAndTime(DateTime date) =>
      '${shortDate(date)}, ${time(date)}';

  static String shortDateAs(DateStyle style, DateTime date) => switch (style) {
    DateStyle.dayMonthName => '${date.day} ${_months[date.month - 1]}',
    DateStyle.dayMonthYear => '${_two(date.day)}/${_two(date.month)}',
    DateStyle.monthDayYear => '${_two(date.month)}/${_two(date.day)}',
    DateStyle.iso => '${_two(date.month)}-${_two(date.day)}',
  };

  static String mediumDateAs(DateStyle style, DateTime date) => switch (style) {
    DateStyle.dayMonthName =>
      '${date.day} ${_months[date.month - 1]} ${date.year}',
    DateStyle.dayMonthYear =>
      '${_two(date.day)}/${_two(date.month)}/${date.year}',
    DateStyle.monthDayYear =>
      '${_two(date.month)}/${_two(date.day)}/${date.year}',
    DateStyle.iso => '${date.year}-${_two(date.month)}-${_two(date.day)}',
  };

  static String timeAs(TimeStyle style, DateTime date) {
    switch (style) {
      case TimeStyle.h24:
        return '${_two(date.hour)}:${_two(date.minute)}';
      case TimeStyle.h12:
        final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
        final suffix = date.hour < 12 ? 'am' : 'pm';
        return '$hour:${_two(date.minute)} $suffix';
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
