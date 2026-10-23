import 'dart:async';

import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/directory_entry.dart';
import '../models/squad_member.dart';
import 'squad_roster_repository.dart';

/// An in-memory [SquadRosterRepository], for tests and for running with no
/// backend.
///
/// Applies the same refusals as the real one: can you place anybody, then do
/// you outrank this person, so a test that passes here cannot rely on
/// something Firestore would reject.
class MockSquadRosterRepository implements SquadRosterRepository {
  MockSquadRosterRepository({
    this.author,
    this.directory = const [],
    List<SquadPlacement> initial = const [],
  }) {
    _placements.addAll(initial);
  }

  /// Who writes are made as. Null stands for signed out, which cannot write.
  final AppUser? author;

  /// Who exists to be placed, and at what role. The real repository reads the
  /// same thing from the directory collection, and for the same reason: the
  /// caller does not get to say what rank the person it is moving holds.
  final List<DirectoryEntry> directory;

  final _placements = <SquadPlacement>[];
  final _changed = StreamController<List<SquadPlacement>>.broadcast();

  /// What is stored, for a test to assert on.
  List<SquadPlacement> get placements => List.unmodifiable(_placements);

  /// The squad somebody is on, or empty when they are on none.
  String squadOf(String userId) {
    for (final placement in _placements) {
      if (placement.userId == userId) return placement.squadId;
    }
    return '';
  }

  @override
  Stream<List<SquadPlacement>> watch() {
    // Stream.multi, not async*: a listener gets the current value at once and
    // every change after it, which is how Firestore's snapshots() behaves.
    return Stream<List<SquadPlacement>>.multi((controller) {
      controller.add(List.unmodifiable(_placements));
      final subscription = _changed.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> place({required String userId, required String squadId}) async {
    if (author == null) {
      throw const AuthException('Sign in to move somebody between squads.');
    }
    if (!SquadRosterRules.canPlaceAnybody(author!.role)) {
      throw const PermissionException(
        'Only leads and managers can move somebody between squads.',
      );
    }

    final target = _roleOf(userId);
    if (target == null) {
      throw const ValidationException(
        'That person is not in your organisation.',
      );
    }

    final problem = SquadRosterRules.problemWithPlacing(
      actorRole: author!.role,
      targetRole: target,
    );
    if (problem != null) throw PermissionException(problem);

    final placement = SquadPlacement(userId: userId, squadId: squadId);
    final index = _placements.indexWhere((p) => p.userId == userId);
    if (index >= 0) {
      _placements[index] = placement;
    } else {
      _placements.add(placement);
    }

    if (!_changed.isClosed) _changed.add(List.unmodifiable(_placements));
  }

  UserRole? _roleOf(String userId) {
    for (final entry in directory) {
      if (entry.id == userId) return entry.role;
    }
    return null;
  }

  void dispose() => _changed.close();
}
