/// The raw numbers for one project over one scoring window.
///
/// This is the boundary between ingestion and scoring: ingestion produces it,
/// the scoring engine consumes it, and neither needs to know about the other.
///
/// Everything here is already aggregated to squad level. No field identifies a
/// person, and none can be traced back to one — that aggregation happens in the
/// anonymiser before these numbers are ever assembled.
class ProjectMetrics {
  const ProjectMetrics({
    required this.projectId,
    required this.windowStart,
    required this.windowEnd,
    required this.commitsInWindow,
    required this.commitsBaseline,
    required this.tasksCompletedInWindow,
    required this.tasksCompletedBaseline,
    required this.openIssueWeight,
    required this.closedIssueWeight,
    required this.budgetSpent,
    required this.budgetTotal,
    required this.scheduleElapsed,
    required this.activeHours,
    required this.availableHours,
    required this.outageHours,
  });

  final String projectId;
  final DateTime windowStart;
  final DateTime windowEnd;

  /// Commits by the whole squad in this window.
  final int commitsInWindow;

  /// What this squad normally does in a window of this length. Comparing a
  /// squad against its own history rather than an industry average is
  /// deliberate: small teams vary enormously and a global benchmark would
  /// flag half of them as failing on day one.
  final double commitsBaseline;

  final int tasksCompletedInWindow;
  final double tasksCompletedBaseline;

  /// Summed complexity of issues still open, and of those closed in this
  /// window. Used as a ratio: if the open pile is getting heavier relative to
  /// what is being cleared, the easy work is being finished first and the hard
  /// work is accumulating.
  final double openIssueWeight;
  final double closedIssueWeight;

  final double budgetSpent;
  final double budgetTotal;

  /// Fraction of the planned schedule that has passed, 0 to 1.
  final double scheduleElapsed;

  /// Hours the squad was actually working.
  final double activeHours;

  /// Hours the squad was rostered to work.
  final double availableHours;

  /// Hours lost to grid outages inside this window. Subtracted from available
  /// hours before anything is scored, so a team is never marked down for a
  /// national power failure.
  final double outageHours;

  /// Available hours with outage time removed — the hours a team could
  /// realistically have worked.
  double get workableHours {
    final workable = availableHours - outageHours;
    return workable > 0 ? workable : 0;
  }

  double get budgetBurn => budgetTotal > 0 ? budgetSpent / budgetTotal : 0;

  Duration get windowLength => windowEnd.difference(windowStart);
}
