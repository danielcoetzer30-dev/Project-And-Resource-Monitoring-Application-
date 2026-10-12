/// Small formatting helpers shared by the dashboard widgets.
///
/// Kept as plain functions so they can be tested without pumping a widget.
library;

import '../../core/utils/date_format.dart';

/// Clock time in whichever format the person chose under Customisations.
/// The default is 24-hour, e.g. "09:05", which is how load-shedding
/// schedules are quoted in South Africa.
String clockTime(DateTime t) => DateFormatting.time(t);

/// How long ago something happened, in the coarsest unit that stays useful.
String agoLabel(DateTime t, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

/// "1 day", "3 days".
String plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// Outage hours to one decimal place, e.g. "6.5 h".
String hoursLabel(num hours) => '${hours.toStringAsFixed(1)} h';
