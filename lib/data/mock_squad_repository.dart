import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/squad_rules.dart';
import 'squad_repository.dart';

/// An in-memory [SquadRepository], for tests and for running with no backend.
///
/// Applies the same refusals as the real one, can you edit at all and is
/// the input valid, so a test that passes here cannot rely on something
/// Firestore would reject.
class MockSquadRepository implements SquadRepository {
  MockSquadRepository({this.author});

  /// Who writes are made as. Null stands for signed out, which cannot write.
  final AppUser? author;

  /// Stored squads, id to (name, headcount), for a test to assert on.
  final squads = <String, ({String name, int headcount})>{};

  var _nextId = 0;

  void _checkCanEdit() {
    if (author == null) throw const AuthException('Sign in to change squads.');
    if (!author!.canChangeSettings) {
      throw const PermissionException(
        'Only leads and managers can create or change squads.',
      );
    }
  }

  void _checkValid(String name, int headcount) {
    final problem =
        SquadRules.nameProblem(name) ??
        SquadRules.headcountProblem('$headcount');
    if (problem != null) throw ValidationException(problem);
  }

  @override
  ({String id, Future<void> saved}) create({
    required String name,
    required int headcount,
  }) {
    _checkCanEdit();
    _checkValid(name, headcount);

    final id = 'mock-squad-${_nextId++}';
    squads[id] = (name: name.trim(), headcount: headcount);
    return (id: id, saved: Future<void>.value());
  }

  @override
  Future<void> update({
    required String squadId,
    required String name,
    required int headcount,
  }) async {
    _checkCanEdit();
    _checkValid(name, headcount);
    if (!squads.containsKey(squadId)) {
      throw const ValidationException('That squad no longer exists.');
    }
    squads[squadId] = (name: name.trim(), headcount: headcount);
  }

  @override
  Future<void> delete(String squadId) async {
    _checkCanEdit();
    squads.remove(squadId);
  }
}
