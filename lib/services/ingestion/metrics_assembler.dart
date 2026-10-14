import '../../models/outage_window.dart';
import '../../models/project_plan.dart';
import '../../models/project_metrics.dart';
import '../../models/squad_activity.dart';

/// Turns one window of squad activity into the metrics the scoring engine
/// consumes.
///
/// This is the join that ingestion has to make and the app never does:
/// measured activity, the team's stated plan, outage windows, and the squad's
/// own recent history all have to meet before a score means anything.
///
/// Baselines come from the squad's past windows, never from an industry
/// average. Small teams vary enormously and a global benchmark would flag half
/// of them as failing on day one — that reasoning is in [ProjectMetrics] too,
/// and it is the reason this class takes a history at all.
class MetricsAssembler {
  const MetricsAssembler();

  /// Windows of history used to work out what normal looks like for a squad.
  ///
  /// Four weeks at the default poll interval is enough to smooth a quiet week
  /// without reaching back to a different phase of the project.
  static const historyWindows = 4;

  /// The period utilisation is measured over. See the note in [assemble].
  static const utilisationDays = 7;

  /// Stored windows needed to cover [utilisationDays] at the default poll
  /// interval, so a week of utilisation can actually be summed.
  static const retainedWindows = 28;

  /// Assembles metrics for one project.
  ///
  /// [history] is previous windows for the same squad, most recent first, and
  /// may be empty — a project in its first window has no baseline, so the
  /// current window becomes its own, which scores as "no change" rather than
  /// as a collapse.
  ProjectMetrics assemble({
    required String projectId,
    required SquadActivity activity,
    required ProjectPlan plan,
    required List<SquadActivity> history,
    required List<OutageWindow> outages,
    required DateTime now,
  }) {
    final commitsBaseline = baselineOf(
      history.map((window) => window.commitCount.toDouble()),
      fallback: activity.commitCount.toDouble(),
    );

    final tasksBaseline = baselineOf(
      history.map((window) => window.tasksCompleted.toDouble()),
      fallback: activity.tasksCompleted.toDouble(),
    );

    // Utilisation is measured over a rolling week, not over the poll window.
    //
    // Scaling a roster down to six hours assumes a team rostered around the
    // clock. They are not: an overnight run would find no activity against a
    // sixth of a week's capacity and report the squad as idle, four times a
    // day, for the entirely normal act of being asleep.
    //
    // A week is the shortest period over which "what did they do with the
    // time they had" has an honest answer, and it matches the period the
    // project document already reports outage hours over.
    final weekStart = now.subtract(const Duration(days: utilisationDays));

    final availableHours = plan.weeklyHours;

    final outageHours = outageHoursIn(
      outages: outages,
      squadId: activity.squadId,
      windowStart: weekStart,
      windowEnd: now,
    );

    // This window, plus every stored window still inside the week.
    final activePersonHours = [
      activity,
      ...history.where((window) => window.windowEnd.isAfter(weekStart)),
    ].fold<int>(0, (sum, window) => sum + window.activePersonHours);

    return ProjectMetrics(
      projectId: projectId,
      windowStart: activity.windowStart,
      windowEnd: activity.windowEnd,
      commitsInWindow: activity.commitCount,
      commitsBaseline: commitsBaseline,
      tasksCompletedInWindow: activity.tasksCompleted,
      tasksCompletedBaseline: tasksBaseline,
      openIssueWeight: activity.openIssueWeight,
      closedIssueWeight: activity.closedIssueWeight,
      budgetSpent: plan.budgetSpent,
      budgetTotal: plan.budgetTotal,
      scheduleElapsed: plan.scheduleElapsedAt(now) ?? 0,
      activeHours: _cappedActiveHours(
        activePersonHours: activePersonHours,
        workableHours: availableHours - outageHours,
      ),
      availableHours: availableHours,
      outageHours: outageHours,
    );
  }

  /// The mean of up to [historyWindows] past windows.
  ///
  /// Public because squad velocity is derived from the same history, and two
  /// implementations of "what normal looks like" would eventually disagree.
  ///
  /// Falls back to the current window when there is no history, which makes
  /// the first run score as no change rather than as a sudden drop to zero.
  double baselineOf(Iterable<double> past, {required double fallback}) {
    final windows = past.take(historyWindows).toList();
    if (windows.isEmpty) return fallback;

    final total = windows.reduce((a, b) => a + b);
    return total / windows.length;
  }

  /// Outage hours overlapping a window for a squad.
  ///
  /// Public because the project document reports a weekly figure while
  /// scoring uses the poll window, and both have to count overlap the same
  /// way or the two numbers will not agree.
  ///
  /// Only the overlapping part is counted. An outage that started before the
  /// window or runs past its end would otherwise remove hours the squad never
  /// had in the first place.
  double outageHoursIn({
    required List<OutageWindow> outages,
    required String squadId,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    var minutes = 0;

    for (final outage in outages) {
      if (outage.affectedSquadIds.isNotEmpty &&
          !outage.affectedSquadIds.contains(squadId)) {
        continue;
      }

      final start = outage.start.isAfter(windowStart)
          ? outage.start
          : windowStart;
      final end = outage.end.isBefore(windowEnd) ? outage.end : windowEnd;

      final overlap = end.difference(start).inMinutes;
      if (overlap > 0) minutes += overlap;
    }

    return minutes / 60;
  }

  /// Hours worked, as close as passive capture can honestly get.
  ///
  /// Capped at the workable hours, so utilisation never exceeds 1. A squad
  /// that touched more hours than it was rostered for has a roster figure
  /// that is wrong, not a superhuman week — and over-commitment is what
  /// `Squad.capacityUsed` reports, not this.
  double _cappedActiveHours({
    required int activePersonHours,
    required double workableHours,
  }) {
    if (workableHours <= 0) return 0;
    final hours = activePersonHours.toDouble();
    return hours > workableHours ? workableHours : hours;
  }
}
