/// Where passively-captured data comes from.
enum SourceType {
  github('GitHub'),
  gitlab('GitLab'),
  clickUp('ClickUp'),
  jira('Jira');

  const SourceType(this.label);

  final String label;

  static SourceType fromName(String name) {
    return SourceType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => SourceType.github,
    );
  }
}

/// A repository or issue tracker the app reads from.
///
/// Note there is no access token on this model. Credentials are held by the
/// backend, never synced to a device and never written to Firestore where a
/// client could read them.
class IngestionSource {
  const IngestionSource({
    required this.id,
    required this.type,
    required this.label,
    required this.remoteId,
    required this.orgId,
    required this.isEnabled,
    this.lastSyncedAt,
  });

  final String id;
  final SourceType type;

  /// What the team calls it, e.g. "Ledger rebuild repo".
  final String label;

  /// The identifier the remote system uses, e.g. "acme/ledger".
  final String remoteId;

  final String orgId;
  final bool isEnabled;

  /// Null until the first successful sync.
  final DateTime? lastSyncedAt;

  bool get hasSynced => lastSyncedAt != null;
}
