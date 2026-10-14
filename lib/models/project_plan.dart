/// The figures a team sets for a project, as opposed to the ones ingestion
/// measures.
///
/// This is the other half of a health score. Commits, tasks and issue weights
/// can be read passively from a repository and a tracker; a budget and a
/// roster cannot, because no system a small team already runs holds them in a
/// readable form. So they are stated once here and read on every scoring run.
///
/// Why this is a separate document from `projects/`:
///
///  - `projects/` is ingestion's output and is read-only to every client, which
///    is what stops a team editing its own scores. Keeping the plan in the same
///    document would mean opening that door.
///  - A plan is owned by people and changes rarely. A score is owned by the
///    machine and changes every run. Mixing them makes it unclear who last
///    wrote what.
///
/// None of this is status entry in the sense constraint 4 rules out. A budget
/// and a roster are setup, like connecting a source: nothing here reports on
/// how the work is going, and nothing here can be moved to flatter a score —
/// spending more of a budget always makes the score worse, never better.
class ProjectPlan {
  const ProjectPlan({
    required this.projectId,
    this.budgetTotal = 0,
    this.budgetSpent = 0,
    this.startDate,
    this.endDate,
    this.weeklyHours = 0,
  });

  final String projectId;

  /// Currency is deliberately not recorded. Only the ratio is ever used, so
  /// storing an amount without a unit cannot produce a wrong conversion.
  final double budgetTotal;
  final double budgetSpent;

  final DateTime? startDate;
  final DateTime? endDate;

  /// Hours the squad is rostered for in a normal week, across the whole squad.
  /// A headcount times a working week, not a per-person figure.
  final double weeklyHours;

  /// True when there is enough here to score budget burn and idle time.
  ///
  /// Checked rather than assumed: a project whose plan was never filled in
  /// should be scored on what is known about it, not on zeroes that would
  /// read as a team spending nothing and working never.
  bool get isUsable =>
      budgetTotal > 0 &&
      weeklyHours > 0 &&
      startDate != null &&
      endDate != null;

  /// How far through the planned schedule we are, 0 to 1, or null when the
  /// dates are missing or make no sense.
  double? scheduleElapsedAt(DateTime now) {
    final start = startDate;
    final end = endDate;
    if (start == null || end == null) return null;

    final total = end.difference(start).inMinutes;
    if (total <= 0) return null;

    final gone = now.difference(start).inMinutes;
    if (gone <= 0) return 0;
    return gone >= total ? 1 : gone / total;
  }

  /// Whole days of schedule left, floored at zero. Null when undatable.
  int? scheduleDaysRemainingAt(DateTime now) {
    final end = endDate;
    if (end == null) return null;

    final left = end.difference(now).inDays;
    return left > 0 ? left : 0;
  }
}
