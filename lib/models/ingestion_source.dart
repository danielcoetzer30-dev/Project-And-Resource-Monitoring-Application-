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
    this.squadId = '',
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

  /// The squad whose work this source represents.
  ///
  /// This is what lets ingestion aggregate without anybody being named: every
  /// contributor to the repository counts towards this squad, and the
  /// anonymiser never has to be told who they are. The contributor threshold
  /// is unaffected — they are still counted, from the events themselves.
  ///
  /// Empty means the source is read and then discarded, because activity that
  /// belongs to no squad cannot be aggregated into anything.
  final String squadId;

  /// Null until the first successful sync.
  final DateTime? lastSyncedAt;

  bool get hasSynced => lastSyncedAt != null;

  /// A copy with some fields changed.
  ///
  /// Added because rebuilding this by hand lost [squadId] twice in the mock
  /// repository — once when allocating an id for a new source and once when
  /// pausing one. A source with no squad is read on every run and thrown
  /// away, so the field going missing is silent and expensive. Listing every
  /// field here once is cheaper than remembering all eight at three call
  /// sites.
  IngestionSource copyWith({
    String? id,
    SourceType? type,
    String? label,
    String? remoteId,
    String? orgId,
    bool? isEnabled,
    String? squadId,
    DateTime? lastSyncedAt,
  }) {
    return IngestionSource(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      remoteId: remoteId ?? this.remoteId,
      orgId: orgId ?? this.orgId,
      isEnabled: isEnabled ?? this.isEnabled,
      squadId: squadId ?? this.squadId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
