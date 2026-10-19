/// One-to-one, or a named group.
enum ConversationKind {
  direct,
  group;

  static ConversationKind fromName(String? name) {
    return ConversationKind.values.firstWhere(
      (kind) => kind.name == name,
      orElse: () => ConversationKind.direct,
    );
  }
}

/// A place messages are sent: a direct conversation between two people, or a
/// group.
///
/// Membership is a list of uids and is what the security rules read to decide
/// who may see a conversation, so nobody outside it can read its messages. A
/// person who is removed from a group stops being able to read it at once.
class Conversation {
  const Conversation({
    required this.id,
    required this.kind,
    required this.memberIds,
    required this.createdBy,
    required this.lastActivity,
    this.name = '',
  });

  final String id;
  final ConversationKind kind;

  /// Set for groups, empty for direct conversations, which are named after the
  /// other person.
  final String name;

  final List<String> memberIds;

  final String createdBy;

  /// When the last message was sent, or when the conversation was made if
  /// nothing has been said yet. Orders the inbox.
  final DateTime lastActivity;

  bool get isGroup => kind == ConversationKind.group;

  bool hasMember(String userId) => memberIds.contains(userId);

  /// The other person in a direct conversation.
  String? otherMemberId(String myId) {
    for (final id in memberIds) {
      if (id != myId) return id;
    }
    return null;
  }

  /// The id every direct conversation between two people shares.
  ///
  /// Derived from the pair, in sorted order, so the same two people always land
  /// in the same conversation instead of starting a new one each time.
  static String directIdFor(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Conversation copyWith({List<String>? memberIds, DateTime? lastActivity}) {
    return Conversation(
      id: id,
      kind: kind,
      name: name,
      memberIds: memberIds ?? this.memberIds,
      createdBy: createdBy,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}
