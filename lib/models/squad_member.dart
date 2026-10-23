import 'app_user.dart';
import 'directory_entry.dart';

/// Who is in which squad, by name.
///
/// The one place a person is attached to a squad, and a deliberate reversal.
///
/// A roster beside published squad metrics re-identifies: naming the two
/// people on a squad whose velocity is down 31% is individual performance
/// data, and `Anonymiser.minimumContributors` cannot prevent it. The team
/// accepted that cost. The research proposal has to say so.
///
/// What still holds:
///
///  - No individual *metric* exists anywhere. `RawActivityEvent` still never
///    leaves memory, the anonymiser still aggregates before storage, and there
///    is no per-person field on any stored document. This adds membership, not
///    measurement.
///  - A placement carries exactly one field, `squadId`. The name and role on
///    screen are read from the directory, so this is not a second place names
///    accumulate.
///  - Placement is an act of management and is recorded as one: only somebody
///    who strictly outranks you may move you, which is why [SquadRosterRules]
///    exists and why `firestore.rules` repeats it.
class SquadPlacement {
  const SquadPlacement({required this.userId, required this.squadId});

  /// The Firebase Auth uid, which is also the document id.
  final String userId;

  /// Empty means in the organisation but on no squad. Unplacing writes an
  /// empty string rather than deleting, so a placement stays a record of a
  /// decision somebody made.
  final String squadId;
}

/// One person as a squad roster shows them: a name, a role, and nothing else.
///
/// Built by joining placements against the directory, never stored. There is
/// deliberately no activity, no capacity and no score on here, a roster says
/// who is on a squad, and the squad card beside it says how the squad is
/// doing.
class RosterMember {
  const RosterMember({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String userId;
  final String displayName;
  final UserRole role;
}

/// Every squad's roster, plus the people on no squad.
///
/// A view model: assembled from the directory and the placements each time
/// either changes, so a name corrected in the directory is corrected here
/// without a second write.
class SquadRoster {
  const SquadRoster({required this.bySquad, required this.unplaced});

  /// Squad id to its members, each list sorted by name.
  final Map<String, List<RosterMember>> bySquad;

  /// In the organisation, on no squad. Sorted by name.
  ///
  /// Shown rather than hidden: somebody who has joined and been forgotten is
  /// the problem this screen is meant to make visible.
  final List<RosterMember> unplaced;

  static const empty = SquadRoster(bySquad: {}, unplaced: []);

  List<RosterMember> of(String squadId) => bySquad[squadId] ?? const [];

  /// How many people are on a squad according to the roster, which can differ
  /// from the squad's stated headcount.
  int countOf(String squadId) => of(squadId).length;

  /// Joins [directory] against [placements].
  ///
  /// Anybody with no placement document, or one with an empty `squadId`, is
  /// unplaced. That makes a new teammate unplaced by default rather than
  /// quietly landing on whichever squad happens to be first.
  factory SquadRoster.from({
    required List<DirectoryEntry> directory,
    required List<SquadPlacement> placements,
  }) {
    final squadOf = <String, String>{
      for (final placement in placements)
        if (placement.squadId.isNotEmpty) placement.userId: placement.squadId,
    };

    final bySquad = <String, List<RosterMember>>{};
    final unplaced = <RosterMember>[];

    for (final entry in directory) {
      final member = RosterMember(
        userId: entry.id,
        displayName: entry.displayName,
        role: entry.role,
      );

      final squadId = squadOf[entry.id];
      if (squadId == null) {
        unplaced.add(member);
      } else {
        bySquad.putIfAbsent(squadId, () => []).add(member);
      }
    }

    int byName(RosterMember a, RosterMember b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());

    for (final members in bySquad.values) {
      members.sort(byName);
    }
    unplaced.sort(byName);

    return SquadRoster(bySquad: bySquad, unplaced: unplaced);
  }
}

/// Who may move whom between squads, in one place so the app, the mock and the
/// security rules agree.
///
/// `firestore.rules` repeats every rule here. If you change one, change both:
/// a check only in the client is a courtesy, and the rules are what actually
/// enforce it.
///
/// The ranking is the one in [UserRole], developer < lead < manager, and the
/// rule is the same one messaging uses for removing somebody from a group: you
/// may place a person only when you strictly outrank them. So a lead places
/// developers, a manager places leads and developers, and nobody places a
/// manager, including themselves.
///
/// Moving somebody between squads changes which aggregate their work is
/// counted in, which is to say it changes what the organisation reports. That
/// is management, not self-service, so there is deliberately no "join a squad"
/// for a developer and no "move myself" for anybody.
abstract final class SquadRosterRules {
  /// Whether [actorRole] can place anybody at all. The gate on the screen.
  static bool canPlaceAnybody(UserRole actorRole) =>
      actorRole.outranks(UserRole.developer);

  /// Whether [actorRole] may move the person whose role is [targetRole].
  static bool canPlace({
    required UserRole actorRole,
    required UserRole targetRole,
  }) {
    return actorRole.outranks(targetRole);
  }

  /// Null when the move is allowed; otherwise what to tell the person.
  static String? problemWithPlacing({
    required UserRole actorRole,
    required UserRole targetRole,
  }) {
    if (!canPlaceAnybody(actorRole)) {
      return 'Only leads and managers can move somebody between squads.';
    }
    if (!canPlace(actorRole: actorRole, targetRole: targetRole)) {
      return 'You can only move somebody whose role is below yours, so a '
          '${actorRole.label.toLowerCase()} cannot move another '
          '${targetRole.label.toLowerCase()}.';
    }
    return null;
  }
}
