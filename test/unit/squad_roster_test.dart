import 'package:flutter_test/flutter_test.dart';

import 'package:prahm/core/errors/exceptions.dart';
import 'package:prahm/data/dto/squad_member_dto.dart';
import 'package:prahm/data/mock_squad_roster_repository.dart';
import 'package:prahm/models/app_user.dart';
import 'package:prahm/models/directory_entry.dart';
import 'package:prahm/models/squad_member.dart';

/// Squad rosters: who may move whom, and what a placement is allowed to carry.
///
/// This is the feature that reversed a privacy position, so the tests that
/// matter most are the ones pinning what was *kept*: a placement is one field,
/// a person is on one squad at a time, and moving somebody is an act of
/// management that needs rank rather than permission in general.
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

  const directory = [
    DirectoryEntry(id: 'mgr', displayName: 'Manager', role: UserRole.manager),
    DirectoryEntry(id: 'lead', displayName: 'Lead', role: UserRole.lead),
    DirectoryEntry(
      id: 'lead2',
      displayName: 'Another lead',
      role: UserRole.lead,
    ),
    DirectoryEntry(id: 'dev', displayName: 'Dev', role: UserRole.developer),
    DirectoryEntry(id: 'dev2', displayName: 'Ada', role: UserRole.developer),
  ];

  MockSquadRosterRepository repositoryFor(
    AppUser? author, {
    List<SquadPlacement> initial = const [],
  }) {
    final repository = MockSquadRosterRepository(
      author: author,
      directory: directory,
      initial: initial,
    );
    addTearDown(repository.dispose);
    return repository;
  }

  group('who may move whom', () {
    test('a manager places a developer', () async {
      final repository = repositoryFor(manager);

      await repository.place(userId: 'dev', squadId: 's1');

      expect(repository.squadOf('dev'), 's1');
    });

    test('a manager places a lead', () async {
      final repository = repositoryFor(manager);

      await repository.place(userId: 'lead', squadId: 's1');

      expect(repository.squadOf('lead'), 's1');
    });

    test('a lead places a developer', () async {
      final repository = repositoryFor(lead);

      await repository.place(userId: 'dev', squadId: 's2');

      expect(repository.squadOf('dev'), 's2');
    });

    test('a lead cannot place another lead', () async {
      // Equal ranks do not outrank each other, the same rule messaging uses
      // for removing somebody from a group. Otherwise two leads could move
      // each other around indefinitely.
      final repository = repositoryFor(lead);

      await expectLater(
        repository.place(userId: 'lead2', squadId: 's1'),
        throwsA(isA<PermissionException>()),
      );

      expect(repository.placements, isEmpty);
    });

    test('a lead cannot place a manager', () async {
      final repository = repositoryFor(lead);

      await expectLater(
        repository.place(userId: 'mgr', squadId: 's1'),
        throwsA(isA<PermissionException>()),
      );
    });

    test('a manager cannot place themselves', () async {
      // Nobody places their own rank or above, so there is no self-service
      // route onto a squad. Which aggregate your work counts in is not
      // yours to choose.
      final repository = repositoryFor(manager);

      await expectLater(
        repository.place(userId: 'mgr', squadId: 's1'),
        throwsA(isA<PermissionException>()),
      );
    });

    test('a developer cannot place anybody, including themselves', () async {
      final repository = repositoryFor(developer);

      await expectLater(
        repository.place(userId: 'dev2', squadId: 's1'),
        throwsA(isA<PermissionException>()),
      );
      await expectLater(
        repository.place(userId: 'dev', squadId: 's1'),
        throwsA(isA<PermissionException>()),
      );

      expect(repository.placements, isEmpty);
    });

    test('signed out is refused', () async {
      final repository = repositoryFor(null);

      await expectLater(
        repository.place(userId: 'dev', squadId: 's1'),
        throwsA(isA<AuthException>()),
      );
    });

    test('somebody outside the organisation is refused', () async {
      // The role is read from the directory rather than taken from the
      // caller, so a screen cannot talk the repository into a move by naming
      // a uid it made up.
      final repository = repositoryFor(manager);

      await expectLater(
        repository.place(userId: 'nobody', squadId: 's1'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('what a placement is', () {
    test('somebody is on one squad at a time', () async {
      // Hours committed to two squads at once would be counted twice, so a
      // move replaces rather than adds.
      final repository = repositoryFor(manager);

      await repository.place(userId: 'dev', squadId: 's1');
      await repository.place(userId: 'dev', squadId: 's2');

      expect(repository.placements, hasLength(1));
      expect(repository.squadOf('dev'), 's2');
    });

    test('taking somebody off a squad keeps the placement', () async {
      // An empty squadId rather than a delete: a placement stays a record of
      // a decision somebody made, and `firestore.rules` refuses the delete.
      final repository = repositoryFor(manager);

      await repository.place(userId: 'dev', squadId: 's1');
      await repository.place(userId: 'dev', squadId: '');

      expect(repository.placements, hasLength(1));
      expect(repository.squadOf('dev'), '');
    });

    test(
      'a listener sees the current roster and every change after it',
      () async {
        final repository = repositoryFor(manager);
        final seen = <int>[];

        final subscription = repository.watch().listen(
          (placements) => seen.add(placements.length),
        );
        addTearDown(subscription.cancel);

        await Future<void>.delayed(Duration.zero);
        await repository.place(userId: 'dev', squadId: 's1');
        await Future<void>.delayed(Duration.zero);

        expect(seen, [0, 1]);
      },
    );
  });

  group('the roster a screen reads', () {
    test('joins names from the directory, never from the placement', () {
      final roster = SquadRoster.from(
        directory: directory,
        placements: const [
          SquadPlacement(userId: 'dev', squadId: 's1'),
          SquadPlacement(userId: 'dev2', squadId: 's1'),
        ],
      );

      expect(roster.of('s1').map((m) => m.displayName), ['Ada', 'Dev']);
      expect(roster.countOf('s1'), 2);
    });

    test('somebody with no placement is unplaced, not quietly on a squad', () {
      final roster = SquadRoster.from(
        directory: directory,
        placements: const [SquadPlacement(userId: 'dev', squadId: 's1')],
      );

      // Sorted by name, so: Ada, Another lead, Lead, Manager.
      expect(roster.unplaced.map((m) => m.userId), [
        'dev2',
        'lead2',
        'lead',
        'mgr',
      ]);
    });

    test('an emptied placement reads as unplaced', () {
      final roster = SquadRoster.from(
        directory: directory,
        placements: const [SquadPlacement(userId: 'dev', squadId: '')],
      );

      expect(roster.of('s1'), isEmpty);
      expect(roster.unplaced.map((m) => m.userId), contains('dev'));
    });

    test('a placement for somebody not in the directory shows nobody', () {
      // A roster is a list of people, and a uid with no directory entry is
      // not a person this organisation can name. Showing the uid would be
      // worse than showing nothing.
      final roster = SquadRoster.from(
        directory: directory,
        placements: const [SquadPlacement(userId: 'ghost', squadId: 's1')],
      );

      expect(roster.of('s1'), isEmpty);
    });

    test('the roster carries a name and a role, read from the directory', () {
      final roster = SquadRoster.from(
        directory: directory,
        placements: const [SquadPlacement(userId: 'dev', squadId: 's1')],
      );

      final member = roster.of('s1').single;

      expect(member.displayName, 'Dev');
      expect(member.role, UserRole.developer);
    });
  });

  group('what a stored placement is allowed to carry', () {
    // The thing this feature must not become. A placement that could carry an
    // hours figure, an activity count or a name would be per-person
    // measurement reached by the back door, and `firestore.rules` accepts
    // only `squadId` and `projectIds`, so if this map ever grows another key,
    // the rules start rejecting every write and the roster silently stops
    // working.
    test('a plain placement is one field, and that field is the squad', () {
      final map = SquadMemberDto.toMap(
        const SquadPlacement(userId: 'dev', squadId: 's1'),
      );

      expect(map.keys, ['squadId']);
      expect(map['squadId'], 's1');
    });

    test('projects are stored as ids, and only when there are any', () {
      final map = SquadMemberDto.toMap(
        const SquadPlacement(
          userId: 'dev',
          squadId: 's1',
          projectIds: ['p1', 'p2'],
        ),
      );

      // The two the rules allow, and nothing else. Ids only: no name, no
      // hours, no figure, which is what keeps this membership rather than
      // measurement.
      expect(map.keys.toSet(), {'squadId', 'projectIds'});
      expect(map['projectIds'], ['p1', 'p2']);
    });

    test('an empty project list is left out rather than written as empty', () {
      // The write replaces the whole document, so omitting the field is what
      // clears it. It also means a plain move sends exactly what it sent
      // before projects existed.
      final map = SquadMemberDto.toMap(
        const SquadPlacement(userId: 'dev', squadId: 's1', projectIds: []),
      );

      expect(map.keys, ['squadId']);
    });
  });

  group('projects within a squad', () {
    test('moving somebody to another squad clears their projects', () async {
      // Otherwise a person stays attached to a project on a squad they have
      // left, and the roster reports work they are no longer doing.
      final repository = repositoryFor(manager);

      await repository.place(
        userId: 'dev',
        squadId: 's1',
        projectIds: ['p1', 'p2'],
      );
      await repository.place(userId: 'dev', squadId: 's2');

      final roster = SquadRoster.from(
        directory: directory,
        placements: repository.placements,
      );

      expect(roster.of('s2').single.projectIds, isEmpty);
    });

    test('somebody on no squad cannot be assigned to a project', () async {
      // `firestore.rules` refuses this too, because a project belongs to a
      // squad: being on none and on one of its projects is not a state.
      final repository = repositoryFor(manager);

      await expectLater(
        repository.place(userId: 'dev', squadId: '', projectIds: ['p1']),
        throwsA(isA<ValidationException>()),
      );
    });

    test('more projects than the rules allow is refused', () async {
      final repository = repositoryFor(manager);

      await expectLater(
        repository.place(
          userId: 'dev',
          squadId: 's1',
          projectIds: List.generate(
            SquadRosterRules.maxProjects + 1,
            (i) => 'p$i',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('the roster reads each person\'s projects from their placement', () {
      final roster = SquadRoster.from(
        directory: directory,
        placements: const [
          SquadPlacement(userId: 'dev', squadId: 's1', projectIds: ['p1']),
          SquadPlacement(userId: 'lead', squadId: 's1'),
        ],
      );

      final withProjects = roster.of('s1').firstWhere((m) => m.userId == 'dev');
      final without = roster.of('s1').firstWhere((m) => m.userId == 'lead');

      expect(withProjects.projectIds, ['p1']);
      expect(without.projectIds, isEmpty);
    });
  });

  group('the rules the screen and the security rules share', () {
    test('only a lead or manager can place anybody', () {
      expect(SquadRosterRules.canPlaceAnybody(UserRole.developer), isFalse);
      expect(SquadRosterRules.canPlaceAnybody(UserRole.lead), isTrue);
      expect(SquadRosterRules.canPlaceAnybody(UserRole.manager), isTrue);
    });

    test('a refusal says who can do it instead', () {
      final problem = SquadRosterRules.problemWithPlacing(
        actorRole: UserRole.lead,
        targetRole: UserRole.lead,
      );

      expect(problem, isNotNull);
      expect(problem, contains('below yours'));
    });
  });
}
