/// What kind of activity an event records.
enum ActivityType { commit, taskCompleted, taskOpened, review }

/// A single raw event, exactly as a source reported it.
///
/// **This type carries an author identifier and must never leave the ingestion
/// layer.** It exists only long enough for the anonymiser to aggregate it away.
/// Nothing in lib/data, lib/screens or lib/state may import this file, and no
/// instance of it is ever written to Firestore or to the local cache.
///
/// The research protocol commits to a system built without individual identity.
/// This class is the one place identity exists at all, deliberately confined to
/// the shortest possible path between a source and the aggregate.
class RawActivityEvent {
  const RawActivityEvent({
    required this.sourceId,
    required this.authorKey,
    required this.occurredAt,
    required this.type,
    this.weight = 1,
  });

  final String sourceId;

  /// Whatever the source uses to identify a person — a username or an email.
  /// Used once, to decide which squad the event belongs to, and then dropped.
  final String authorKey;

  final DateTime occurredAt;
  final ActivityType type;

  /// Relative size of the item, for complexity weighting. Story points where a
  /// tracker provides them, 1 otherwise.
  final double weight;
}
