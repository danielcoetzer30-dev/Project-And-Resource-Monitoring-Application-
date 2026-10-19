import '../models/ingestion_source.dart';

/// The repositories and trackers an organisation reads activity from.
///
/// One of the three things a client may write, and the only one that changes
/// what the whole organisation is measured on. `firestore.rules` gates it to
/// leads and managers, and refuses any document carrying a token.
///
/// **Credentials never pass through here.** A source records *what* to read —
/// a repository name, a board id — and never *how* to authenticate. The token
/// lives in the ingestion job's secrets, where the app cannot reach it and a
/// stolen phone does not carry it. [connect] takes no token for that reason,
/// and the rules refuse one even if a future caller tried.
abstract interface class SourceRepository {
  /// Every source for the signed-in user's organisation, newest sync first.
  Stream<List<IngestionSource>> watch();

  /// Adds a source, or replaces one with the same id.
  Future<void> connect(IngestionSource source);

  /// Stops a source being read without forgetting it.
  ///
  /// Separate from [disconnect] because a team pausing a noisy tracker for a
  /// fortnight should not have to retype its id afterwards, and because the
  /// scores it already produced stay explainable if the source is still there.
  Future<void> setEnabled({required String sourceId, required bool enabled});

  /// Forgets a source entirely.
  Future<void> disconnect(String sourceId);
}
