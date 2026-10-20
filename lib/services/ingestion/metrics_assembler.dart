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

  /// How many past windows to keep.
  ///
  /// Only the one before this is read, but the margin matters. Runs are daily
  /// over a fortnight, so the window this one is compared against is the one
  /// stored fourteen runs ago — retaining exactly fourteen would put that
  /// lookup on the boundary, and a single skipped run would drop the baseline
  /// and report "not enough history" to a team that has plenty.
  static const retainedWindows = 21;

  /// Assembles metrics for one project.
  ///
  /// [history] is previous windows for the same squad, most recent first, and
  /// may be empty — a project in its first window has no baseline, and the
  /// calculators say so rather than inventing one.
  ProjectMetrics assemble({
    required String projectId,
    required SquadActivity activity,
    required ProjectPlan plan,
    required List<SquadActivity> history,
    required List<OutageWindow> outages,
    required DateTime now,
  }) {
    // Compared against the equivalent window a window-length earlier, not
    // against a mean of the stored ones.
    //
    // Runs overlap: a seven-day window read every day shares six days with
    // yesterday's. Averaging those would compare this week against itself and
    // report "steady" through almost anything. Week against the week before
    // is both honest and the question a team actually asks.
    final previous = windowBefore(activity: activity, history: history);

    // Zero when there is nothing to compare against, never the current
    // window standing in for its own baseline.
    //
    // That substitution was here and it was wrong: it produced a ratio of
    // exactly 1, and the calculators reported "steady against this squad's
    // own baseline" from a run that had no baseline at all. Zero takes the
    // guard clause each calculator already has, which says "not enough
    // history yet" and scores the neutral middle. There was never a collapse
    // to protect against — a zero baseline has always returned 60, not 0.
    final commitsBaseline = previous?.commitCount.toDouble() ?? 0;
    final tasksBaseline = previous?.tasksCompleted.toDouble() ?? 0;

    // Everything below is scaled to the activity window, which is also the
    // period utilisation is measured over.
    //
    // That used to be two different periods, and summing stored windows to
    // reach a week was right when a run covered six hours. It is wrong now: a
    // seven-day window read daily would sum seven overlapping weeks and
    // report roughly seven times the work actually done.
    final windowMinutes = activity.windowEnd
        .difference(activity.windowStart)
        .inMinutes;

    const weekMinutes = Duration.minutesPerHour * Duration.hoursPerDay * 7;

    final availableHours = windowMinutes <= 0
        ? 0.0
        : plan.weeklyHours * (windowMinutes / weekMinutes);

    final outageHours = outageHoursIn(
      outages: outages,
      squadId: activity.squadId,
      windowStart: activity.windowStart,
      windowEnd: activity.windowEnd,
    );

    final activePersonHours = activity.activePersonHours;

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

  /// The stored window covering the period immediately before [activity].
  ///
  /// Only windows that ended before this one opened are eligible. Runs
  /// overlap — a seven-day window read daily shares six days with
  /// yesterday's — and comparing a week against six of its own days would
  /// report "steady" through almost anything.
  ///
  /// Of those, the most recent wins, so a skipped run compares against the
  /// closest week there is rather than against nothing.
  ///
  /// Null when there is no such window, which makes a squad's first run its
  /// own baseline: no change, rather than a sudden drop to zero.
  ///
  /// Public because squad velocity is derived from the same comparison, and
  /// two implementations of "what normal looks like" would eventually
  /// disagree.
  SquadActivity? windowBefore({
    required SquadActivity activity,
    required List<SquadActivity> history,
  }) {
    final candidates = history
        .where((window) => !window.windowEnd.isAfter(activity.windowStart))
        .toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.windowEnd.compareTo(a.windowEnd));
    return candidates.first;
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
