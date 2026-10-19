import 'app_user.dart';

/// Somebody who can be messaged.
///
/// The directory exists because `users` is readable only by its owner, so
/// nothing else lets one person find another. It is deliberately thin: a name
/// and a role, which is what a person needs to pick a recipient and what the
/// group rules need to show who may remove whom.
///
/// There is no email, no squad and no activity here, and nothing links an entry
/// to a squad or a project. Squads still have a headcount and never a member
/// list. The directory says who is in the organisation, not what they do.
///
/// Each person writes only their own entry, and `firestore.rules` refuses one
/// whose role differs from the role on their real `users` document. The role
/// shown here is therefore a display copy: the rules never trust it when
/// deciding who may remove whom.
class DirectoryEntry {
  const DirectoryEntry({
    required this.id,
    required this.displayName,
    required this.role,
  });

  /// The Firebase Auth uid.
  final String id;

  final String displayName;

  final UserRole role;
}
