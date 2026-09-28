import '../../data/project_repository.dart';
import '../../models/outage_window.dart';

/// Works out what outages cost a squad, and keeps that cost out of scoring.
///
/// The whole argument of the research rests on this separation. Existing tools
/// see a quiet week and record underdelivery; this service sees a quiet week
/// with eleven hours of load-shedding in it and records a team that worked the
/// hours it had. The numbers it produces are fed to the scoring engine as
/// *excluded* time, never as a penalty.
class OutageService {
  const OutageService();

  /// Hours a squad lost to outages inside a window.
  ///
  /// Overlap is computed rather than assumed: an outage running 16:00–18:30
  /// against a working day ending at 17:00 costs one hour, not two and a half.
  double hoursLostBySquad({
    required String squadId,
    required List<OutageWindow> windows,
    required DateTime windowStart,
    required DateTime windowEnd,
    int workDayStartHour = 8,
    int workDayEndHour = 17,
  }) {
    var totalMinutes = 0;

    for (final outage in windows) {
      if (!outage.affectedSquadIds.contains(squadId)) continue;

      final overlapStart = outage.start.isAfter(windowStart)
          ? outage.start
          : windowStart;
      final overlapEnd = outage.end.isBefore(windowEnd)
          ? outage.end
          : windowEnd;
      if (!overlapEnd.isAfter(overlapStart)) continue;

      totalMinutes += _workingMinutesBetween(
        overlapStart,
        overlapEnd,
        workDayStartHour,
        workDayEndHour,
      );
    }

    return totalMinutes / 60;
  }

  /// Capacity adjusted for scheduled outages.
  ///
  /// Used for forecasting rather than scoring: it answers "how much can this
  /// squad realistically commit to next sprint", which is a planning question
  /// a team lead can act on before the sprint rather than after it.
  double adjustedCapacityHours({
    required double rosteredHours,
    required double forecastOutageHours,
  }) {
    final adjusted = rosteredHours - forecastOutageHours;
    return adjusted > 0 ? adjusted : 0;
  }

  /// Current grid state, assembled for the dashboard strip.
  GridStatus gridStatus({
    required int stage,
    required List<OutageWindow> upcoming,
    required double hoursLostThisWeek,
  }) {
    final future = upcoming.where((w) => w.isUpcoming).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final next = future.isEmpty ? null : future.first;

    return GridStatus(
      stage: stage,
      nextOutageStart: next?.start,
      nextOutageEnd: next?.end,
      hoursLostThisWeek: hoursLostThisWeek,
    );
  }

  /// Minutes of overlap that fall inside working hours.
  ///
  /// An outage at two in the morning costs a team nothing, and counting it
  /// would inflate "hours lost" to the point where the figure stopped meaning
  /// anything.
  int _workingMinutesBetween(
    DateTime start,
    DateTime end,
    int dayStartHour,
    int dayEndHour,
  ) {
    var minutes = 0;
    var cursor = start;

    while (cursor.isBefore(end)) {
      final dayStart = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        dayStartHour,
      );
      final dayEnd = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        dayEndHour,
      );

      // Weekends are not counted. Small teams do work them, but counting them
      // by default would overstate the loss for most.
      final isWeekend =
          cursor.weekday == DateTime.saturday ||
          cursor.weekday == DateTime.sunday;

      if (!isWeekend) {
        final segmentStart = cursor.isAfter(dayStart) ? cursor : dayStart;
        final segmentEnd = end.isBefore(dayEnd) ? end : dayEnd;
        if (segmentEnd.isAfter(segmentStart)) {
          minutes += segmentEnd.difference(segmentStart).inMinutes;
        }
      }

      // Move to the start of the next day.
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    return minutes;
  }
}
