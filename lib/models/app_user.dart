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

  ///Every query in the app is scoped by this.
  final String orgId;

  final UserRole role;

  bool get canChangeSettings => role != UserRole.developer;
}
