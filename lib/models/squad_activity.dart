/// Aggregated activity for one squad over one window.
///
/// This is what ingestion is allowed to produce. Every field is a count or a
/// total across the whole squad; there is no field that could identify a
/// person, and no list from which one could be reconstructed.
///
/// [contributorCount] is a number, not a set of names. It exists so the
/// anonymiser can check that an aggregate actually aggregates something,
/// a "squad total" covering one person is that person's activity wearing a
/// different label.
class SquadActivity {
  const SquadActivity({
    required this.squadId,
    required this.windowStart,
    required this.windowEnd,
    required this.commitCount,
    required this.tasksCompleted,
    required this.tasksOpened,
    required this.closedIssueWeight,
    required this.openIssueWeight,
    required this.contributorCount,
    this.activePersonHours = 0,
  });

  final String squadId;
  final DateTime windowStart;
  final DateTime windowEnd;

  final int commitCount;
  final int tasksCompleted;
  final int tasksOpened;

  /// Summed complexity of items closed and still open in this window.
  final double closedIssueWeight;
  final double openIssueWeight;

  /// How many distinct people contributed. A count only.
  final int contributorCount;

  /// Distinct person-hours in which anything happened, summed across the
  /// squad: two people active in the same hour counts as two.
  ///
  /// The closest thing to "hours worked" that passive capture can honestly
  /// produce. A commit says somebody was working in that hour; it says
  /// nothing about the rest of the hour, so this counts hours touched rather
  /// than pretending to measure effort.
  ///
  /// It is an aggregate like every other field here. The hour an individual
  /// worked is used to compute it and then discarded, exactly as an author
  /// key is used to compute [commitCount] and then discarded, and squads
  /// below the contributor threshold never reach this type at all.
  final int activePersonHours;

  bool get hasActivity => commitCount > 0 || tasksCompleted > 0;
}
