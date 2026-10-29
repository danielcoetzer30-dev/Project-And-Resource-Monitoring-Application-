import 'package:flutter_test/flutter_test.dart';

import 'package:prahm/core/errors/exceptions.dart';
import 'package:prahm/data/mock_squad_repository.dart';
import 'package:prahm/models/app_user.dart';
import 'package:prahm/models/squad_rules.dart';

/// Creating, renaming and deleting a squad.
///
/// What a squad is called and how many people it says it has are stated by a
/// person. Everything else a squad card shows is measured by ingestion, and
/// this repository has no way to write any of it, which is the same
/// separation that keeps project scores out of the app's reach.
void main() {
  const manager = AppUser(
    id: 'mgr',
    email: 'mgr@example.com',
    displayName: 'Manager',
    orgId: 'demo-org',
    role: UserRole.manager,
  );

  const lead = AppUser(
    id: 'lead',
    email: 'lead@example.com',
    displayName: 'Lead',
    orgId: 'demo-org',
    role: UserRole.lead,
  );

  const developer = AppUser(
    id: 'dev',
    email: 'dev@example.com',
    displayName: 'Dev',
    orgId: 'demo-org',
    role: UserRole.developer,
  );

  group('who may change what the organisation is divided into', () {
    test('a lead and a manager may', () async {
      expect(
        () => MockSquadRepository(author: manager).create(
          name: 'Platform',
          headcount: 4,
        ),
        returnsNormally,
      );
      expect(
        () => MockSquadRepository(author: lead).create(
          name: 'Platform',
          headcount: 4,
        ),
        returnsNormally,
      );
    });

    test('a developer may not', () async {
      // The screen hides this and the route refuses it, but the refusal lives
      // here too, so the gate is not only in the interface.
      final repository = MockSquadRepository(author: developer);

      expect(
        () => repository.create(name: 'Platform', headcount: 4),
        throwsA(isA<PermissionException>()),
      );
      await expectLater(
        repository.update(squadId: 's1', name: 'Platform', headcount: 4),
        throwsA(isA<PermissionException>()),
      );
      await expectLater(
        repository.delete('s1'),
        throwsA(isA<PermissionException>()),
      );
    });

    test('nobody signed out may', () async {
      expect(
        () => MockSquadRepository().create(name: 'Platform', headcount: 4),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('creating', () {
    test('returns an id before the server has answered', () async {
      // The screen uses the id immediately, so a squad can be opened and
      // filled while the write is still in flight, or queued offline.
      final repository = MockSquadRepository(author: manager);

      final created = repository.create(name: 'Platform', headcount: 4);

      expect(created.id, isNotEmpty);
      await expectLater(created.saved, completes);
      expect(repository.squads[created.id]?.name, 'Platform');
    });

    test('trims the name it stores', () async {
      final repository = MockSquadRepository(author: manager);

      final created = repository.create(name: '  Platform  ', headcount: 4);

      expect(repository.squads[created.id]?.name, 'Platform');
    });

    test('refuses what the form and the rules refuse', () async {
      final repository = MockSquadRepository(author: manager);

      expect(
        () => repository.create(name: '', headcount: 4),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => repository.create(
          name: 'Platform',
          headcount: SquadRules.maxHeadcount + 1,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('renaming', () {
    test('changes the stated fields and nothing else', () async {
      final repository = MockSquadRepository(author: manager);
      final created = repository.create(name: 'Platform', headcount: 4);

      await repository.update(
        squadId: created.id,
        name: 'Platform and Data',
        headcount: 6,
      );

      expect(repository.squads[created.id]?.name, 'Platform and Data');
      expect(repository.squads[created.id]?.headcount, 6);
    });

    test('a squad that no longer exists is refused rather than recreated', () async {
      // Two people editing at once: the other one deleted it. Recreating it
      // here would resurrect a squad somebody decided to remove.
      final repository = MockSquadRepository(author: manager);

      await expectLater(
        repository.update(squadId: 'gone', name: 'Platform', headcount: 4),
        throwsA(isA<ValidationException>()),
      );
      expect(repository.squads, isEmpty);
    });
  });

  test('deleting removes it', () async {
    final repository = MockSquadRepository(author: manager);
    final created = repository.create(name: 'Platform', headcount: 4);

    await repository.delete(created.id);

    expect(repository.squads, isEmpty);
  });
}
