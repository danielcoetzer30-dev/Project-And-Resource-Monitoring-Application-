/// What a signed-in person is allowed to see.
///
/// Roles exist to limit access, not to grant it: a manager sees squad-level
/// summaries only. There is no role anywhere in this app that can view
/// individual developer activity, because that data is never stored.
enum UserRole {
  developer('Developer'),
  lead('Lead'),
  manager('Manager');

  const UserRole(this.label);

  final String label;

  /// Higher outranks lower. The declaration order above *is* the rank order —
  /// developer, then lead, then manager — so reordering the values changes who
  /// may remove whom in a group. `messaging_rules_test.dart` pins it.
  int get rank => index;

  /// True when this role is strictly above [other]. Equal roles do not
  /// outrank each other, so a lead cannot remove another lead.
  bool outranks(UserRole other) => rank > other.rank;

  static UserRole fromName(String name) {
    return UserRole.values.firstWhere(
      (role) => role.name == name,
      orElse: () => UserRole.developer,
    );
  }
}

/// A signed-in user.
///
/// Deliberately thin. It carries who you are and which organisation you belong
/// to, and nothing about what you have done — activity is aggregated to squad
/// level before storage and is never attached to a user.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.orgId,
    required this.role,
  });

  final String id;
  final String email;
  final String displayName;

  /// Every query in the app is scoped by this.
  final String orgId;

  final UserRole role;

  bool get isDeveloper => role == UserRole.developer;
  bool get isLead => role == UserRole.lead;
  bool get isManager => role == UserRole.manager;

  /// Leads and managers can change what the team is measured on. A developer
  /// can read every setting, which is the point: the scoring has to be
  /// inspectable by the people it scores.
  bool get canChangeSettings => role != UserRole.developer;

  // Deliberately no per-project permission. Every project in an organisation
  // is visible to every member and writable by none, so there is nothing for
  // such a check to decide. See "Per-project ownership" in CLAUDE.md.

  factory AppUser.fromMap(Map<String, dynamic> map, String documentId) {
    return AppUser(
      id: documentId,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      orgId: map['orgId'] ?? '',
      role: UserRole.fromName(map['role'] ?? 'developer'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'orgId': orgId,
      'role': role.name,
    };
  }
}
