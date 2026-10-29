/// Creating, renaming and deleting squads.
///
/// Separate from `ProjectRepository`, which reads ingestion's output and has
/// no write method, for the same reason project plans are: what a squad is
/// called is something a person states, and how it is doing is something
/// ingestion measures. This interface can write the first and never the
/// second.
///
/// Leads and managers only. See `SquadRules` for what may be saved.
abstract interface class SquadRepository {
  /// Creates a squad and returns its new id at once, so a caller can use it
  /// before the server answers.
  ///
  /// Throws synchronously if the caller may not create squads or the input is
  /// invalid. Otherwise `saved` completes when the server confirms; offline
  /// that may be hours away, so callers should not block a screen on it.
  ({String id, Future<void> saved}) create({
    required String name,
    required int headcount,
  });

  /// Changes a squad's name and stated headcount. Nothing measured changes.
  Future<void> update({
    required String squadId,
    required String name,
    required int headcount,
  });

  /// Deletes a squad. The caller is responsible for checking that nobody is
  /// placed on it and no project belongs to it: security rules cannot count.
  Future<void> delete(String squadId);
}
