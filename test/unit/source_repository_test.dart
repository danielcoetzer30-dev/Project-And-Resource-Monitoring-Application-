import 'package:flutter_test/flutter_test.dart';

import 'package:prahm/core/errors/exceptions.dart';
import 'package:prahm/data/dto/source_dto.dart';
import 'package:prahm/data/mock_source_repository.dart';
import 'package:prahm/models/app_user.dart';
import 'package:prahm/models/ingestion_source.dart';

/// Connecting a source decides what the whole organisation is measured on, so
/// it is gated the same way scoring weights are, and it is the one write that
/// could plausibly carry a credential, so it is the one that must not.
void main() {
  const lead = AppUser(
    id: 'lead-uid',
    email: 'lead@example.com',
    displayName: 'Lead',
    orgId: 'demo-org',
    role: UserRole.lead,
  );

  const developer = AppUser(
    id: 'dev-uid',
    email: 'dev@example.com',
    displayName: 'Dev',
    orgId: 'demo-org',
    role: UserRole.developer,
  );

  IngestionSource source({
    String id = '',
    String label = 'Keel repo',
    String remoteId = 'rrousselGit/riverpod',
    SourceType type = SourceType.github,
    bool isEnabled = true,
    String squadId = 's1',
  }) {
    return IngestionSource(
      id: id,
      type: type,
      label: label,
      remoteId: remoteId,
      orgId: 'demo-org',
      isEnabled: isEnabled,
      squadId: squadId,
    );
  }

  group('who may change a source', () {
    test('a lead connects one', () async {
      final repository = MockSourceRepository(author: lead);
      addTearDown(repository.dispose);

      await repository.connect(source());

      expect(repository.sources, hasLength(1));
      expect(repository.sources.single.remoteId, 'rrousselGit/riverpod');
    });

    test('a developer is refused, and nothing is written', () async {
      final repository = MockSourceRepository(author: developer);
      addTearDown(repository.dispose);

      await expectLater(
        repository.connect(source()),
        throwsA(isA<PermissionException>()),
      );

      expect(repository.sources, isEmpty);
    });

    test('signed out is refused', () async {
      final repository = MockSourceRepository();
      addTearDown(repository.dispose);

      await expectLater(
        repository.connect(source()),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('a credential never reaches the document', () {
    test('toMap writes what ingestion needs and no credential', () {
      final map = SourceDto.toMap(source(id: 'src-1'));

      expect(map.keys.toSet(), {
        'type',
        'label',
        'remoteId',
        'isEnabled',
        'squadId',
      });

      // firestore.rules refuses a source document carrying any of these, so a
      // write that included one would fail rather than quietly store a secret.
      for (final forbidden in ['token', 'accessToken', 'apiKey']) {
        expect(map.containsKey(forbidden), isFalse, reason: forbidden);
      }
    });

    test('lastSyncedAt is read but never written back', () {
      // Ingestion owns that field. Writing it from the app would let a team
      // make a dead source look healthy.
      expect(SourceDto.toMap(source()).containsKey('lastSyncedAt'), isFalse);
    });
  });

  group('what counts as a usable address', () {
    test('a GitHub source wants owner/repository', () {
      expect(
        SourceRules.remoteIdProblem(SourceType.github, 'riverpod'),
        contains('owner/repository'),
      );
      expect(
        SourceRules.remoteIdProblem(SourceType.github, 'rrousselGit/riverpod'),
        isNull,
      );
    });

    test('a wrong shape is refused before it can look like silence', () async {
      // A bad id returns 404 from the remote system, which reaches the team as
      // "no activity" rather than "wrong address". Catching it here is the
      // difference between a typo and a fortnight of flat scores.
      final repository = MockSourceRepository(author: lead);
      addTearDown(repository.dispose);

      await expectLater(
        repository.connect(source(remoteId: 'not a repo')),
        throwsA(isA<ValidationException>()),
      );

      expect(repository.sources, isEmpty);
    });

    test('a ClickUp list is digits, a Jira key is capitals', () {
      expect(
        SourceRules.remoteIdProblem(SourceType.clickUp, '901234567'),
        isNull,
      );
      expect(
        SourceRules.remoteIdProblem(SourceType.clickUp, 'board'),
        isNotNull,
      );
      expect(SourceRules.remoteIdProblem(SourceType.jira, 'PRAHM'), isNull);
      expect(SourceRules.remoteIdProblem(SourceType.jira, 'prahm'), isNotNull);
    });

    test('a source needs a name somebody will recognise', () {
      expect(SourceRules.labelProblem('   '), isNotNull);
      expect(SourceRules.labelProblem('Ledger repo'), isNull);
    });

    test('a source with no squad is refused rather than read and dropped', () {
      // The squad is what lets the anonymiser aggregate without anybody being
      // named. Without one the source would be fetched on every run and its
      // every event discarded, which looks exactly like a repository with no
      // activity in it.
      final problem = SourceRules.problemWith(source(squadId: ''));

      expect(problem, contains('squad'));
    });
  });

  group('pausing and forgetting', () {
    test('disabling keeps the source so it need not be retyped', () async {
      final repository = MockSourceRepository(
        author: lead,
        initial: [source(id: 'src-1')],
      );
      addTearDown(repository.dispose);

      await repository.setEnabled(sourceId: 'src-1', enabled: false);

      expect(repository.sources, hasLength(1));
      expect(repository.sources.single.isEnabled, isFalse);
    });

    test('disconnecting forgets it', () async {
      final repository = MockSourceRepository(
        author: lead,
        initial: [source(id: 'src-1')],
      );
      addTearDown(repository.dispose);

      await repository.disconnect('src-1');

      expect(repository.sources, isEmpty);
    });

    test('a developer can neither pause nor forget', () async {
      final repository = MockSourceRepository(
        author: developer,
        initial: [source(id: 'src-1')],
      );
      addTearDown(repository.dispose);

      await expectLater(
        repository.setEnabled(sourceId: 'src-1', enabled: false),
        throwsA(isA<PermissionException>()),
      );
      await expectLater(
        repository.disconnect('src-1'),
        throwsA(isA<PermissionException>()),
      );

      expect(repository.sources.single.isEnabled, isTrue);
    });
  });

  test('watching emits the current list and every change after it', () async {
    final repository = MockSourceRepository(author: lead);
    addTearDown(repository.dispose);

    final seen = <int>[];
    final subscription = repository.watch().listen((s) => seen.add(s.length));

    await Future<void>.delayed(Duration.zero);
    await repository.connect(source(label: 'One'));
    await repository.connect(source(label: 'Two'));
    await Future<void>.delayed(Duration.zero);

    await subscription.cancel();

    expect(seen, [0, 1, 2]);
  });
}
