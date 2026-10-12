/// One message in the discussion attached to a signal.
///
/// A comment lives next to the warning it is about, so the conversation about
/// why a project went critical is still there next week instead of scrolled
/// away in a chat. It is deliberately not a messaging feature: there is no
/// editing, no reactions, no mentions and no thread of threads.
///
/// **The author is whoever wrote the comment, never someone being measured.**
/// Attribution is what makes a discussion readable, but it is also the one
/// place a person's name sits beside project data, so it is fenced in:
///
///  - Nothing in the app queries comments by author or counts them per person.
///    Counts, where they exist, are per signal.
///  - Comments are not part of `HealthSnapshot`, so `SnapshotBrief` cannot send
///    them to the assistant. Free text can name people; the assistant only ever
///    receives squad-level data.
///  - Nothing ingestion produces is ever attached to a comment, and nothing a
///    comment says feeds a score.
class Comment {
  const Comment({
    required this.id,
    required this.body,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.isPending = false,
  });

  final String id;

  /// What was said, already trimmed.
  final String body;

  /// The Firebase Auth uid of the author. Used to decide who may delete the
  /// comment and enforced by the security rules; never shown.
  final String authorId;

  /// The author's display name when they wrote it. A snapshot rather than a
  /// lookup, because `users` documents are readable only by their owner.
  final String authorName;

  final DateTime createdAt;

  /// True while the write is queued on this device and not yet confirmed by
  /// the server. Connectivity is unreliable by assumption, so a comment written
  /// during an outage says so rather than pretending it has been delivered.
  final bool isPending;
}

/// What may be posted, in one place so the app, the mock and the security
/// rules agree.
///
/// `firestore.rules` repeats [maxLength]. If you change one, change both.
abstract final class CommentRules {
  static const maxLength = 1000;

  /// Length as the security rules count it: characters, after trimming.
  static int lengthOf(String raw) => raw.trim().runes.length;

  /// Null when [raw] can be posted; otherwise what to tell the person.
  static String? problemWith(String raw) {
    final length = lengthOf(raw);
    if (length == 0) return 'Write something first.';
    if (length > maxLength) {
      return 'Keep it to $maxLength characters or fewer.';
    }
    return null;
  }
}
