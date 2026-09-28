/// Aggregated activity for one squad over one window.
///
/// This is what ingestion is allowed to produce. Every field is a count or a
/// total across the whole squad; there is no field that could identify a
/// person, and no list from which one could be reconstructed.
///
/// [contributorCount] is a number, not a set of names. It exists so the
/// anonymiser can check that an aggregate actually aggregates something —
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

  bool get hasActivity => commitCount > 0 || tasksCompleted > 0;
}
