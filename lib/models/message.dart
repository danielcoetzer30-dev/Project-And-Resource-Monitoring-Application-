/// One message in a conversation.
///
/// Messages are people talking to people. They are not part of
/// `HealthSnapshot`, so `SnapshotBrief` cannot send them to the assistant, and
/// nothing ingestion produces is ever attached to one. Nothing queries them by
/// sender or counts them per person.
class Message {
  const Message({
    required this.id,
    required this.body,
    required this.senderId,
    required this.senderName,
    required this.createdAt,
    this.isPending = false,
  });

  final String id;

  /// What was said, already trimmed.
  final String body;

  /// The Firebase Auth uid of the sender. Enforced by the security rules, so a
  /// message cannot be attributed to somebody who did not send it.
  final String senderId;

  /// The sender's display name when they sent it. A snapshot rather than a
  /// lookup, so a message still reads correctly if that person later leaves
  /// the group.
  final String senderName;

  final DateTime createdAt;

  /// True while the write is queued on this device and not yet confirmed by the
  /// server, so a message sent during an outage says so instead of pretending
  /// it was delivered.
  final bool isPending;
}
