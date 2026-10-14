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

    final windowLength = activity.windowEnd.difference(activity.windowStart);

    // Rostered hours, scaled from a week down to this window. A six-hour poll
    // window is not a week of capacity.
    final availableHours = plan.weeklyHours <= 0
        ? 0.0
        : plan.weeklyHours *
              (windowLength.inMinutes / const Duration(days: 7).inMinutes);

    final outageHours = outageHoursIn(
      outages: outages,
      squadId: activity.squadId,
      windowStart: activity.windowStart,
      windowEnd: activity.windowEnd,
    );

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
      // There is no passive source for hours actually worked, so activity in
      // the window stands in for it: a squad that committed and closed tasks
      // was working. It is a proxy and is documented as one — see the note on
      // idle time in docs/SCHEMA.md.
      activeHours: _activeHoursProxy(
        activity: activity,
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

  /// A stand-in for hours worked, derived from whether the squad was active.
  ///
  /// Deliberately crude, and capped at the workable hours so it can never
  /// claim a squad worked more than it could have. A squad with no activity at
  /// all reports zero; any activity reports the full workable window, because
  /// the alternative — guessing a fraction from a commit count — would invent
  /// precision the data does not support.
  double _activeHoursProxy({
    required SquadActivity activity,
    required double workableHours,
  }) {
    if (workableHours <= 0) return 0;
    return activity.hasActivity ? workableHours : 0;
  }
}
