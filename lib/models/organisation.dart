/// The team or company that owns a set of projects.
///
/// Everything in Firestore hangs off an organisation, so one team can never
/// read another's data — the security rules check membership against this id.
class Organisation {
  const Organisation({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.memberCount,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  /// The number of users in this organisation, A count not a list.
  final int memberCount;

  bool get isSmallTeam => memberCount < 16;
}
