/// Small formatting helpers shared by the dashboard widgets.
///
/// Kept as plain functions so they can be tested without pumping a widget.
library;

/// 24-hour clock, e.g. "09:05". Load-shedding schedules are quoted this way
/// in South Africa, so it matches what the team already reads elsewhere.
String clockTime(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

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
