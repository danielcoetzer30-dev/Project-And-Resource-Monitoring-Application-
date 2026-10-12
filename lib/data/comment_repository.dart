import '../models/comment.dart';

/// Discussion on a signal, as an interface.
///
/// Kept apart from [ProjectRepository] on purpose. That one is written by
/// ingestion and is read-only to the app, which is what stops a team editing
/// its own health scores. This one is written by people. Mixing them would put
/// a write method on the interface whose whole point is that it has none.
///
/// Comments never feed a score and never reach the assistant.
abstract interface class CommentRepository {
  /// The thread for one signal, oldest first, live. Emits immediately from the
  /// local cache when offline.
  Stream<List<Comment>> watch(String signalId);

  /// Adds a comment as the signed-in user.
  ///
  /// Offline, the returned future does not complete until the server confirms,
  /// while [watch] already shows the comment as pending. Callers should not
  /// block the screen on it.
  Future<void> add({required String signalId, required String body});

  /// Deletes a comment. Only its author is allowed to; the security rules
  /// enforce that, and the UI offers it only on your own comments.
  Future<void> delete({required String signalId, required String commentId});
}
