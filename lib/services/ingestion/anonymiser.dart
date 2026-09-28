import '../../models/activity_event.dart';
import '../../models/squad_activity.dart';

/// Strips individual identity from ingested activity.
///
/// This is the single most important file in the ingestion layer, and the one
/// the research protocol depends on. Section D of the proposal commits to a
/// system "deliberately built without any individual identity", aggregating to
/// squad level, with management barred from granular developer analytics.
///
/// Everything that enters this class carries an author. Nothing that leaves it
/// does. That is the whole contract, and [anonymiseTest] in the test suite
/// exists to fail loudly if it is ever broken.
///
/// ## Why a minimum contributor count
///
/// Aggregating to squad level only protects someone if the squad has more than
/// one person in it. A "squad total" covering a single contributor is that
/// person's individual activity with a different label on it — technically
/// aggregated, practically identifying.
///
/// So squads below [minimumContributors] are dropped rather than reported. The
/// cost is that a genuinely tiny squad produces no metrics; the alternative is
/// per-person surveillance that happens to be spelled "squad".
class Anonymiser {
  const Anonymiser({required this.squadOfAuthor, this.minimumContributors = 2});

  /// Maps a source's author key to a squad id.
  ///
  /// Held in memory for the duration of one ingestion run and never persisted.
  /// The mapping itself is identifying, so it lives in configuration owned by
  /// the team, not in the monitoring database.
  final Map<String, String> squadOfAuthor;

  /// Below this many distinct contributors, an aggregate is not anonymous.
  final int minimumContributors;

  /// Aggregates raw events into squad-level activity.
  ///
  /// Events whose author cannot be mapped to a squad are discarded. Silently
  /// bucketing them into an "unknown" squad would produce a group that is
  /// often one person.
  List<SquadActivity> anonymise({
    required List<RawActivityEvent> events,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    final commits = <String, int>{};
    final tasksCompleted = <String, int>{};
    final tasksOpened = <String, int>{};
    final closedWeight = <String, double>{};
    final openWeight = <String, double>{};
    final contributors = <String, Set<String>>{};

    for (final event in events) {
      if (event.occurredAt.isBefore(windowStart) ||
          event.occurredAt.isAfter(windowEnd)) {
        continue;
      }

      final squadId = squadOfAuthor[event.authorKey];
      if (squadId == null) continue;

      // The author key is used here and nowhere else. It goes into a set only
      // so the set's *size* can be checked below; the set itself is local and
      // is discarded when this method returns.
      contributors.putIfAbsent(squadId, () => <String>{}).add(event.authorKey);

      switch (event.type) {
        case ActivityType.commit:
        case ActivityType.review:
          commits[squadId] = (commits[squadId] ?? 0) + 1;
        case ActivityType.taskCompleted:
          tasksCompleted[squadId] = (tasksCompleted[squadId] ?? 0) + 1;
          closedWeight[squadId] = (closedWeight[squadId] ?? 0) + event.weight;
        case ActivityType.taskOpened:
          tasksOpened[squadId] = (tasksOpened[squadId] ?? 0) + 1;
          openWeight[squadId] = (openWeight[squadId] ?? 0) + event.weight;
      }
    }

    final results = <SquadActivity>[];

    for (final entry in contributors.entries) {
      final squadId = entry.key;
      final contributorCount = entry.value.length;

      // The threshold check. A squad that does not clear it produces nothing.
      if (contributorCount < minimumContributors) continue;

      results.add(
        SquadActivity(
          squadId: squadId,
          windowStart: windowStart,
          windowEnd: windowEnd,
          commitCount: commits[squadId] ?? 0,
          tasksCompleted: tasksCompleted[squadId] ?? 0,
          tasksOpened: tasksOpened[squadId] ?? 0,
          closedIssueWeight: closedWeight[squadId] ?? 0,
          openIssueWeight: openWeight[squadId] ?? 0,
          contributorCount: contributorCount,
        ),
      );
    }

    results.sort((a, b) => a.squadId.compareTo(b.squadId));
    return results;
  }

  /// Squads that had activity but were suppressed for being too small.
  ///
  /// Returned as ids only, so the app can tell a team "this squad is too small
  /// to report on anonymously" rather than silently showing nothing. Knowing a
  /// squad was suppressed reveals nothing about who is in it.
  List<String> suppressedSquads({
    required List<RawActivityEvent> events,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    final contributors = <String, Set<String>>{};

    for (final event in events) {
      if (event.occurredAt.isBefore(windowStart) ||
          event.occurredAt.isAfter(windowEnd)) {
        continue;
      }
      final squadId = squadOfAuthor[event.authorKey];
      if (squadId == null) continue;
      contributors.putIfAbsent(squadId, () => <String>{}).add(event.authorKey);
    }

    return contributors.entries
        .where((e) => e.value.length < minimumContributors)
        .map((e) => e.key)
        .toList()
      ..sort();
  }
}
