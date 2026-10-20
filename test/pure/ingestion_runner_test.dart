import 'package:test/test.dart';

import 'package:keel/models/activity_event.dart';
import 'package:keel/models/ingestion_source.dart';
import 'package:keel/services/health_scoring/health_score_engine.dart';
import 'package:keel/services/ingestion/anonymiser.dart';
import 'package:keel/services/ingestion/firestore_rest.dart';
import 'package:keel/services/ingestion/ingestion_adapter.dart';
import 'package:keel/services/ingestion/ingestion_runner.dart';
import 'package:keel/services/ingestion/ingestion_service.dart';

/// An in-memory [FirestoreStore], so the runner can be exercised without
/// touching the research database.
class FakeStore implements FirestoreStore {
  FakeStore(this.documents);

  /// Full path to fields.
  final Map<String, Map<String, dynamic>> documents;

  final deleted = <String>[];

  @override
  Future<Map<String, dynamic>?> get(String path) async => documents[path];

  @override
  Future<Map<String, Map<String, dynamic>>> list(String collectionPath) async {
    final found = <String, Map<String, dynamic>>{};

    for (final entry in documents.entries) {
      final path = entry.key;
      if (!path.startsWith('$collectionPath/')) continue;

      final rest = path.substring(collectionPath.length + 1);
      // A document directly in this collection, not in a subcollection.
      if (rest.contains('/')) continue;

      found[rest] = entry.value;
    }

    return found;
  }

  @override
  Future<void> write(
    String path,
    Map<String, dynamic> data, {
    List<String>? mergeFields,
  }) async {
    final existing = documents[path];
    if (existing == null || mergeFields == null) {
      documents[path] = {...data};
      return;
    }
    documents[path] = {...existing, ...data};
  }

  @override
  Future<void> delete(String path) async {
    documents.remove(path);
    deleted.add(path);
  }
}

/// Stands in for GitHub, so the pipeline can be driven without a network or a
/// token.
///
/// Builds its events relative to the window it is asked for, exactly as a real
/// adapter does. Returning events at fixed times instead would make every run
/// after the first one find nothing, which is a property of the test rather
/// than of the code.
class StubAdapter implements IngestionAdapter {
  StubAdapter(this.authorKeys);

  /// One commit each, inside whatever window is requested.
  final List<String> authorKeys;

  @override
  SourceType get type => SourceType.github;

  @override
  Future<List<RawActivityEvent>> fetchEvents({
    required IngestionSource source,
    required DateTime since,
    required String token,
  }) async => [
    for (final key in authorKeys)
      RawActivityEvent(
        sourceId: source.id,
        authorKey: key,
        occurredAt: since.add(const Duration(minutes: 1)),
        type: ActivityType.commit,
      ),
    for (final key in authorKeys)
      RawActivityEvent(
        sourceId: source.id,
        authorKey: key,
        occurredAt: since.add(const Duration(minutes: 2)),
        type: ActivityType.taskCompleted,
      ),
  ];
}

/// The runner is what finally makes scores move, and it writes the collection
/// the whole research argument rests on. What is tested here is that it writes
/// the right thing, and that constraint 1 still holds on the path where an
/// aggregate turns into a stored score.
void main() {
  final now = DateTime.utc(2026, 10, 14, 12);

  Map<String, Map<String, dynamic>> seedDocuments() => {
    'organisations/demo-org/sources/src-1': {
      'type': 'github',
      'label': 'keel repo',
      'remoteId': 'team/keel',
      'isEnabled': true,
    },
    'organisations/demo-org/projects/proj-1': {
      'name': 'Ledger rebuild',
      'client': 'Northbank',
      'squadId': 'squad-platform',
      'score': 50.0,
      'seam': <dynamic>[],
    },
    'organisations/demo-org/projectPlans/proj-1': {
      'budgetTotal': 400000.0,
      'budgetSpent': 376000.0,
      'startDate': DateTime.utc(2026, 8, 1),
      'endDate': DateTime.utc(2026, 10, 30),
      'weeklyHours': 120.0,
    },
  };

  /// Two contributors by default, so the anonymiser lets the aggregate
  /// through.
  IngestionRunner runnerOver(
    FakeStore store, {
    List<String> authors = const ['thabo', 'naledi'],
  }) {
    return IngestionRunner(
      firestore: store,
      orgId: 'demo-org',
      engine: HealthScoreEngine.standard(),
      service: IngestionService(
        adapters: [StubAdapter(authors)],
        anonymiser: const Anonymiser(
          squadOfAuthor: {
            'thabo': 'squad-platform',
            'naledi': 'squad-platform',
          },
        ),
      ),
    );
  }

  test('scores a project and writes it where the app reads it', () async {
    final store = FakeStore(seedDocuments());

    final report = await runnerOver(
      store,
    ).run(tokensBySourceId: const {'src-1': 'token'}, now: now);

    expect(report.projectsScored, 1);

    final written = store.documents['organisations/demo-org/projects/proj-1']!;

    // A real score replaced the seeded 50, and the five factors came with it.
    expect(written['score'], isNot(50.0));
    expect(written['factors'], hasLength(5));
    expect(written['updatedAt'], now);

    // Budget burn came from the plan document, not from the repository.
    expect(written['budgetBurn'], closeTo(376000 / 400000, 0.0001));
    expect(written['scheduleDaysRemaining'], 15);

    // Fields a person set are untouched by a scoring run.
    expect(written['name'], 'Ledger rebuild');
    expect(written['client'], 'Northbank');
  });

  test('a one-person squad is suppressed and never gets a score', () async {
    final store = FakeStore(seedDocuments());
    final before =
        store.documents['organisations/demo-org/projects/proj-1']!['score'];

    final report = await runnerOver(
      store,
      authors: const ['thabo'],
    ).run(tokensBySourceId: const {'src-1': 'token'}, now: now);

    // Constraint 1 at the point it would matter most: a squad total covering
    // one person is that person's data, so nothing is written at all.
    expect(report.projectsScored, 0);
    expect(report.suppressedSquads, contains('squad-platform'));
    expect(report.skipped['proj-1'], contains('suppressed'));

    final after = store.documents['organisations/demo-org/projects/proj-1']!;
    expect(after['score'], before, reason: 'the seeded score must stand');
    expect(after.containsKey('updatedAt'), isFalse);
  });

  test('the seam gets one segment per day, not one per run', () async {
    final store = FakeStore(seedDocuments());
    final runner = runnerOver(store);

    await runner.run(tokensBySourceId: const {'src-1': 'token'}, now: now);
    await runner.run(
      tokensBySourceId: const {'src-1': 'token'},
      now: now.add(const Duration(hours: 6)),
    );

    final seam =
        store.documents['organisations/demo-org/projects/proj-1']!['seam']
            as List;

    expect(seam, hasLength(1), reason: 'both runs fall on 14 Oct');
    expect((seam.single as Map)['periodLabel'], '14 Oct');

    await runner.run(
      tokensBySourceId: const {'src-1': 'token'},
      now: now.add(const Duration(days: 1)),
    );

    final grown =
        store.documents['organisations/demo-org/projects/proj-1']!['seam']
            as List;

    expect(grown, hasLength(2));
    expect((grown.last as Map)['periodLabel'], '15 Oct');
  });

  test(
    'a signal that no longer holds is cleared, not left to pile up',
    () async {
      final documents = seedDocuments();

      // Left over from a previous run, for a project that is fine now.
      documents['organisations/demo-org/signals/proj-1-stale'] = {
        'title': 'Something that was true last week',
        'projectId': 'proj-1',
        'severity': 'atRisk',
      };

      final store = FakeStore(documents);

      await runnerOver(
        store,
      ).run(tokensBySourceId: const {'src-1': 'token'}, now: now);

      expect(
        store.deleted,
        contains('organisations/demo-org/signals/proj-1-stale'),
      );
    },
  );

  test('writes the fields the forecast and the Week tab depend on', () async {
    final documents = seedDocuments();

    // A fortnight apart, so the first run's window has closed before the
    // second one opens. Runs closer together overlap, and an overlapping
    // window is not a baseline — it is thirteen-fourteenths of the same days.
    final second = now.add(const Duration(days: 15));

    // An outage inside the week the second run reports, overlapping it only
    // partly: the hours before that week opened were never this squad's to
    // lose. Positioned against the second run rather than the first, because
    // the project document always reports the most recent week.
    documents['organisations/demo-org/outages/out-1'] = {
      'stage': 4,
      'start': second.subtract(const Duration(days: 2, hours: 1)),
      'end': second.subtract(const Duration(days: 2)),
      'affectedSquadIds': ['squad-platform'],
    };

    final store = FakeStore(documents);
    final runner = runnerOver(store);

    await runner.run(tokensBySourceId: const {'src-1': 'token'}, now: now);
    await runner.run(tokensBySourceId: const {'src-1': 'token'}, now: second);

    final written = store.documents['organisations/demo-org/projects/proj-1']!;

    // Without this the forecaster pairs a fresh burn rate with a stale
    // velocity and gives a confidently wrong completion date.
    expect(written['velocityRatio'], isA<double>());
    expect(written['velocityRatio'], closeTo(1, 0.0001));

    // One hour of overlap, reported over the week rather than the window.
    expect(written['loadSheddingHoursLost'], closeTo(1, 0.0001));
  });

  test('updates the squad, without touching what the team stated', () async {
    final documents = seedDocuments();
    documents['organisations/demo-org/squads/squad-platform'] = {
      'name': 'Platform squad',
      'headcount': 4,
      'weeklyHours': 160.0,
      'capacityUsed': 0.5,
      'activeProjectCount': 0,
      'velocityTrend': 0.0,
    };

    final store = FakeStore(documents);
    final runner = runnerOver(store);

    await runner.run(tokensBySourceId: const {'src-1': 'token'}, now: now);
    await runner.run(
      tokensBySourceId: const {'src-1': 'token'},
      now: now.add(const Duration(hours: 6)),
    );

    final squad =
        store.documents['organisations/demo-org/squads/squad-platform']!;

    expect(squad['activeProjectCount'], 1);
    expect(squad['velocityTrend'], closeTo(0, 0.0001));

    // 120 committed hours against the 160 the squad says it has.
    expect(squad['capacityUsed'], closeTo(120 / 160, 0.0001));

    // Neither a headcount nor a squad's hours is something a commit log
    // knows, so neither is overwritten.
    expect(squad['name'], 'Platform squad');
    expect(squad['headcount'], 4);
    expect(squad['weeklyHours'], 160.0);
  });

  test('a squad that has not stated its hours gets no capacity', () async {
    // The bug this replaced: capacity was committed hours over a headcount
    // times a forty-hour week. That assumed everybody is full-time on this
    // work, and a part-time squad read as permanently idle — eleven per cent
    // from four people against eighteen committed hours. A number about the
    // assumption, not about the team. With no stated hours there is no
    // answer, so none is written.
    final documents = seedDocuments();
    documents['organisations/demo-org/squads/squad-platform'] = {
      'name': 'Platform squad',
      'headcount': 4,
      'capacityUsed': 0.88,
    };

    final store = FakeStore(documents);

    await runnerOver(
      store,
    ).run(tokensBySourceId: const {'src-1': 'token'}, now: now);

    final squad =
        store.documents['organisations/demo-org/squads/squad-platform']!;

    expect(squad['capacityUsed'], 0.88, reason: 'the stated value stands');
    expect(squad['activeProjectCount'], 1, reason: 'this is measurable');
  });

  test('a squad with no plan hours keeps its stated capacity', () async {
    final documents = seedDocuments();
    documents.remove('organisations/demo-org/projectPlans/proj-1');
    documents['organisations/demo-org/squads/squad-platform'] = {
      'name': 'Platform squad',
      'headcount': 4,
      'capacityUsed': 0.88,
    };

    final store = FakeStore(documents);

    await runnerOver(
      store,
    ).run(tokensBySourceId: const {'src-1': 'token'}, now: now);

    final squad =
        store.documents['organisations/demo-org/squads/squad-platform']!;

    // Zero would render as an idle team rather than as an unanswered
    // question, so the previous value stands.
    expect(squad['capacityUsed'], 0.88);
    expect(squad['activeProjectCount'], 1);
  });

  test('backfill stores past windows without backdating any score', () async {
    final store = FakeStore(seedDocuments());

    final lines = await runnerOver(store).backfillHistory(
      tokensBySourceId: const {'src-1': 'token'},
      now: now,
      windows: 3,
    );

    expect(lines, hasLength(3));

    const path =
        'organisations/demo-org/'
        '${IngestionRunner.activityHistoryCollection}/squad-platform';

    expect((store.documents[path]!['windows'] as List), hasLength(3));

    // A score is a statement about a project now. Backdating one would put a
    // verdict on the seam for a day nobody was watching.
    final project = store.documents['organisations/demo-org/projects/proj-1']!;
    expect(project.containsKey('updatedAt'), isFalse);
    expect(project['score'], 50.0, reason: 'the seeded score is untouched');
  });

  test('backfilled windows do not overlap each other', () async {
    final store = FakeStore(seedDocuments());

    await runnerOver(store).backfillHistory(
      tokensBySourceId: const {'src-1': 'token'},
      now: now,
      windows: 3,
    );

    const path =
        'organisations/demo-org/'
        '${IngestionRunner.activityHistoryCollection}/squad-platform';

    final windows = (store.documents[path]!['windows'] as List)
        .cast<Map<String, dynamic>>();

    // Newest first, and each one ends exactly where the next begins. An
    // overlap here would be a baseline comparing a fortnight against part of
    // itself, which reports "steady" through anything.
    for (var i = 0; i < windows.length - 1; i++) {
      expect(
        windows[i]['windowStart'],
        windows[i + 1]['windowEnd'],
        reason: 'window $i overlaps the one before it',
      );
    }
  });

  group('a plan is how a project comes into existence', () {
    test('a plan with no project yet gets one built from it', () async {
      final documents = seedDocuments();
      documents.remove('organisations/demo-org/projects/proj-1');
      documents['organisations/demo-org/projectPlans/proj-1'] = {
        'name': 'Ledger rebuild',
        'client': 'Northbank',
        'squadId': 'squad-platform',
        'budgetTotal': 400000.0,
        'budgetSpent': 376000.0,
        'startDate': DateTime.utc(2026, 8, 1),
        'endDate': DateTime.utc(2026, 10, 30),
        'weeklyHours': 120.0,
      };

      final store = FakeStore(documents);

      final report = await runnerOver(
        store,
      ).run(tokensBySourceId: const {'src-1': 'token'}, now: now);

      expect(report.projectsCreated, 1);

      final project =
          store.documents['organisations/demo-org/projects/proj-1']!;

      // Identity comes from the plan; the score comes from this run. That
      // split is the whole reason the app can offer project setup while
      // `projects` stays unwritable by every client.
      expect(project['name'], 'Ledger rebuild');
      expect(project['client'], 'Northbank');
      expect(project['squadId'], 'squad-platform');
      expect(project['score'], isNot(50.0), reason: 'it was scored too');
    });

    test('renaming a project in its plan renames it everywhere', () async {
      final documents = seedDocuments();
      documents['organisations/demo-org/projectPlans/proj-1'] = {
        'name': 'Ledger rebuild II',
        'client': 'Northbank',
        'squadId': 'squad-platform',
      };

      final store = FakeStore(documents);

      await runnerOver(
        store,
      ).run(tokensBySourceId: const {'src-1': 'token'}, now: now);

      expect(
        store.documents['organisations/demo-org/projects/proj-1']!['name'],
        'Ledger rebuild II',
      );
    });

    test('an archived plan stops its project being scored', () async {
      final documents = seedDocuments();
      documents['organisations/demo-org/projectPlans/proj-1'] = {
        'name': 'Ledger rebuild',
        'squadId': 'squad-platform',
        'isArchived': true,
      };

      final store = FakeStore(documents);

      final report = await runnerOver(
        store,
      ).run(tokensBySourceId: const {'src-1': 'token'}, now: now);

      final project =
          store.documents['organisations/demo-org/projects/proj-1']!;

      expect(report.projectsScored, 0);
      expect(project['isArchived'], isTrue);

      // Marked, not deleted. The history and the seam are the research
      // record, and a project that went wrong is the one most worth keeping.
      expect(project['score'], 50.0, reason: 'the previous score stands');
      expect(project.containsKey('updatedAt'), isFalse);
    });

    test('the squad on the plan wins over the one on the project', () async {
      // The plan is what the team stated; the project document is this job's
      // own output. Moving a project to another squad has to work.
      final documents = seedDocuments();
      documents['organisations/demo-org/projects/proj-1'] = {
        ...documents['organisations/demo-org/projects/proj-1']!,
        'squadId': 'squad-gone',
      };
      documents['organisations/demo-org/projectPlans/proj-1'] = {
        'name': 'Ledger rebuild',
        'squadId': 'squad-platform',
      };

      final store = FakeStore(documents);

      final report = await runnerOver(
        store,
      ).run(tokensBySourceId: const {'src-1': 'token'}, now: now);

      expect(report.projectsScored, 1);
    });
  });

  test('the squad history it writes carries no identity', () async {
    final store = FakeStore(seedDocuments());

    await runnerOver(
      store,
    ).run(tokensBySourceId: const {'src-1': 'token'}, now: now);

    const path =
        'organisations/demo-org/'
        '${IngestionRunner.activityHistoryCollection}/squad-platform';

    final history = store.documents[path]!;

    final window = (history['windows'] as List).single as Map;

    // A contributor count is a number. An author key is not allowed anywhere
    // near a stored document, and the history is stored.
    expect(window['contributorCount'], 2);
    expect(window.toString(), isNot(contains('thabo')));
    expect(window.toString(), isNot(contains('naledi')));
  });
}
