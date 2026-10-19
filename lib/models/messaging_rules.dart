import 'app_user.dart';

/// Who may do what in messaging, in one place so the app, the mock and the
/// security rules agree.
///
/// `firestore.rules` repeats every limit and every permission here. If you
/// change one, change both: a check only in the client is a courtesy, and the
/// rules are what actually enforce it.
///
/// Three roles, ranked developer < lead < manager:
///
///  - Leads and managers create groups and add people to them. Developers do
///    neither.
///  - A person may remove somebody only when they strictly outrank them. A
///    manager can remove a lead or a developer, a lead can remove a developer,
///    and nobody can remove their own rank or above. Two managers cannot remove
///    each other, and neither can two leads.
///  - Anyone can leave a group themselves, whatever their role.
///  - Direct messages are open to everyone in the organisation, whether or not
///    they share a group.
abstract final class MessagingRules {
  static const maxMessageLength = 2000;
  static const maxGroupNameLength = 60;
  static const maxGroupSize = 50;

  /// Length as the security rules count it: characters, after trimming.
  static int lengthOf(String raw) => raw.trim().runes.length;

  /// Null when [raw] can be sent; otherwise what to tell the person.
  static String? problemWithMessage(String raw) {
    final length = lengthOf(raw);
    if (length == 0) return 'Write something first.';
    if (length > maxMessageLength) {
      return 'Keep it to $maxMessageLength characters or fewer.';
    }
    return null;
  }

  /// Null when [raw] can name a group; otherwise what to tell the person.
  static String? problemWithGroupName(String raw) {
    final length = lengthOf(raw);
    if (length == 0) return 'Give the group a name.';
    if (length > maxGroupNameLength) {
      return 'Keep the name to $maxGroupNameLength characters or fewer.';
    }
    return null;
  }

  static bool canCreateGroup(UserRole role) =>
      role.outranks(UserRole.developer);

  static bool canAddMembers(UserRole role) => role.outranks(UserRole.developer);

  /// Whether [actorId] may take [targetId] out of a group.
  ///
  /// Leaving is always allowed. Removing somebody else needs a strictly higher
  /// rank, which is what keeps leads from removing managers and peers from
  /// removing each other.
  static bool canRemove({
    required String actorId,
    required UserRole actorRole,
    required String targetId,
    required UserRole targetRole,
  }) {
    if (actorId == targetId) return true;
    return actorRole.outranks(targetRole);
  }
}
