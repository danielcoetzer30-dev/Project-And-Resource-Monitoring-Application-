import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/squad_member.dart';
import 'dto/squad_member_dto.dart';
import 'squad_roster_repository.dart';

/// Squad placements, in the signed-in user's organisation.
///
/// Checks the rank before writing so the app can say why a move was refused,
/// and relies on `firestore.rules` to make that check more than a courtesy.
class FirestoreSquadRosterRepository implements SquadRosterRepository {
  FirestoreSquadRosterRepository({
    required this.orgId,
    this.author,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String orgId;

  /// Who writes are made as. Null when signed out, which cannot write.
  final AppUser? author;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _members =>
      _org.collection(AppConstants.squadMembersCollection);

  DocumentReference<Map<String, dynamic>> get _org =>
      _firestore.collection(AppConstants.organisationsCollection).doc(orgId);

  @override
  Stream<List<SquadPlacement>> watch() {
    // Signed out means no organisation to scope to. An unscoped query would be
    // refused anyway; empty says so without an error screen.
    if (orgId.isEmpty) return Stream.value(const []);

    return _members.snapshots().map(
      (snapshot) => [
        for (final doc in snapshot.docs) SquadMemberDto.fromDoc(doc),
      ],
    );
  }

  @override
  Future<void> place({
    required String userId,
    required String squadId,
    List<String> projectIds = const [],
  }) async {
    if (squadId.isEmpty && projectIds.isNotEmpty) {
      throw const ValidationException(
        'Choose a squad before choosing projects.',
      );
    }
    if (projectIds.length > SquadRosterRules.maxProjects) {
      throw ValidationException(
        'Choose at most ${SquadRosterRules.maxProjects} projects.',
      );
    }
    if (author == null) {
      throw const AuthException('Sign in to move somebody between squads.');
    }
    if (!SquadRosterRules.canPlaceAnybody(author!.role)) {
      throw const PermissionException(
        'Only leads and managers can move somebody between squads.',
      );
    }

    // The target's role is read here rather than taken from the caller, so a
    // screen cannot talk the repository into a move by passing a lower role
    // than the person actually has. The rules read it again from `users`.
    final problem = SquadRosterRules.problemWithPlacing(
      actorRole: author!.role,
      targetRole: await _targetRole(userId),
    );
    if (problem != null) throw PermissionException(problem);

    try {
      await _members
          .doc(userId)
          .set(
            SquadMemberDto.toMap(
              SquadPlacement(
                userId: userId,
                squadId: squadId,
                projectIds: projectIds,
              ),
            ),
          );
    } on FirebaseException catch (error) {
      // Said rather than thrown raw: the screen reports an AppException, and
      // anything else would vanish and leave the roster looking unchanged.
      throw switch (error.code) {
        'permission-denied' => const PermissionException(
          'The backend refused this move. Check that the latest security '
          'rules are published and that that squad exists in the database.',
        ),
        'unavailable' || 'deadline-exceeded' => const NetworkException(
          'The device could not reach the backend.',
        ),
        _ => ValidationException('The move could not be saved (${error.code}).'),
      };
    }
  }

  /// The role on the target's directory entry.
  ///
  /// The directory is a display copy each person writes about themselves, and
  /// the rules refuse an entry whose role differs from their real `users`
  /// document, so it is safe to read here, and it is the only copy a client
  /// can read at all. `users` is readable only by its owner, deliberately.
  Future<UserRole> _targetRole(String userId) async {
    final doc = await _org
        .collection(AppConstants.directoryCollection)
        .doc(userId)
        .get();

    if (!doc.exists) {
      throw const ValidationException(
        'That person is not in your organisation.',
      );
    }

    return UserRole.fromName(doc.data()?['role'] as String? ?? 'developer');
  }
}
