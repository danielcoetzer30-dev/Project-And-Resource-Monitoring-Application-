/// Human-readable durations.
///
/// Both of these were previously reimplemented on two screens each, with
/// slightly different rounding — one said "2h ago" where the other said
/// "1h ago" for the same instant.
abstract final class DurationFormatting {
  /// "3h ago", "2d ago". Used on signals and sync badges.
  static String ago(DateTime moment, {DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(moment);

    if (elapsed.isNegative) return 'just now';
    if (elapsed.inMinutes < 1) return 'just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
    if (elapsed.inDays < 30) return '${elapsed.inDays}d ago';
    return '${(elapsed.inDays / 30).floor()}mo ago';
  }

  /// "6.5h" — outage hours, where the half matters.
  static String hours(double value) => '${value.toStringAsFixed(1)}h';

  /// "2h 30m" — for a window length rather than a total.
  static String span(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
