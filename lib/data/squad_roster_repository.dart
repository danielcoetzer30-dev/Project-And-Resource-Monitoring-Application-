import '../models/squad_member.dart';

/// Who is in which squad.
///
/// Deliberately not on `ProjectRepository` and not on a squad document: that
/// interface reads ingestion's output and has no write method, and a squad is
/// written by ingestion alone. Placements are written by people, so they live
/// in their own collection with their own rule — the same split that keeps a
/// project plan apart from a project.
///
/// Reading is open to every member of the organisation. A roster only
/// management could see would be a worse thing than one everybody can see:
/// people are entitled to know which aggregate their work is counted in.
/// Writing needs a role that strictly outranks the person being moved, which
/// is [SquadRosterRules].
abstract interface class SquadRosterRepository {
  /// Every placement in the organisation, live.
  Stream<List<SquadPlacement>> watch();

  /// Puts [userId] on [squadId], or takes them off every squad when [squadId]
  /// is empty.
  ///
  /// Replaces whatever placement they had: somebody is on one squad at a time,
  /// because hours committed to two squads at once would be counted twice.
  Future<void> place({required String userId, required String squadId});
}
