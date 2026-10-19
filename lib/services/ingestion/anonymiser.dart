import '../../models/activity_event.dart';
import '../../models/ingestion_source.dart';
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
  const Anonymiser({
    this.squadOfAuthor = const {},
    this.squadOfSource = const {},
    this.minimumContributors = 2,
  });

  /// Maps a source's author key to a squad id.
  ///
  /// Held in memory for the duration of one ingestion run and never persisted.
  /// The mapping itself is identifying, so it lives in configuration owned by
  /// the team, not in the monitoring database.
  ///
  /// Needed only when one source feeds several squads. Where a repository
  /// belongs to a single squad — which is the common case — [squadOfSource]
  /// does the same job without naming anybody, and is preferred for that
  /// reason: it is one fewer place a person's identity has to be written down.
  final Map<String, String> squadOfAuthor;

  /// Maps a source id to the squad that works on it.
  ///
  /// The whole of a repository's activity belongs to one squad, so nobody has
  /// to be listed for the aggregate to be built. Contributors are still
  /// counted, in memory, from the events themselves — the threshold below
  /// does not weaken because the configuration got simpler.
  final Map<String, String> squadOfSource;

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

    // Distinct (person, hour) pairs per squad. Only the *size* of each set
    // leaves this method, for the same reason as [contributors] below: there
    // is no honest way to count hours worked without touching whose hours
    // they were, so it is touched here and discarded here.
    final activeSlots = <String, Set<String>>{};

    for (final event in events) {
      if (event.occurredAt.isBefore(windowStart) ||
          event.occurredAt.isAfter(windowEnd)) {
        continue;
      }

      final squadId = _squadFor(event);
      if (squadId == null) continue;

      // The author key is used here and nowhere else. It goes into a set only
      // so the set's *size* can be checked below; the set itself is local and
      // is discarded when this method returns.
      contributors.putIfAbsent(squadId, () => <String>{}).add(event.authorKey);

      activeSlots
          .putIfAbsent(squadId, () => <String>{})
          .add('${event.authorKey}@${_hourKey(event.occurredAt)}');

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
          activePersonHours: activeSlots[squadId]?.length ?? 0,
        ),
      );
    }

    results.sort((a, b) => a.squadId.compareTo(b.squadId));
    return results;
  }

  /// This anonymiser, plus the squad each of [sources] belongs to.
  ///
  /// Called by [IngestionService] on every run, so the mapping comes from the
  /// source documents a team maintains rather than from configuration that
  /// has to be kept in step with them by hand.
  Anonymiser forSources(List<IngestionSource> sources) {
    return Anonymiser(
      squadOfAuthor: squadOfAuthor,
      squadOfSource: {
        for (final source in sources)
          if (source.squadId.isNotEmpty) source.id: source.squadId,
      },
      minimumContributors: minimumContributors,
    );
  }

  /// Which squad an event belongs to, or null when nothing says.
  ///
  /// A per-person mapping wins where one exists, so a shared repository can
  /// still be split between squads. Otherwise the source decides.
  String? _squadFor(RawActivityEvent event) =>
      squadOfAuthor[event.authorKey] ?? squadOfSource[event.sourceId];

  /// An hour, as a string, in UTC.
  ///
  /// UTC rather than local so a squad spread across a timezone boundary, or a
  /// job that runs in one region and a team that works in another, cannot
  /// double-count the same hour.
  static String _hourKey(DateTime at) {
    final utc = at.toUtc();
    return '${utc.year}-${utc.month}-${utc.day}T${utc.hour}';
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
      final squadId = _squadFor(event);
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
