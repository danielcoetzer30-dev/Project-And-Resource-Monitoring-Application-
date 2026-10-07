import 'package:flutter_test/flutter_test.dart';

import 'package:keel/data/mock_project_repository.dart';
import 'package:keel/services/assistant/snapshot_brief.dart';

/// The brief is the only thing in the app that sends project data to a third
/// party, so these tests are about what leaves the device, not formatting.
void main() {
  late MockProjectRepository repo;

  setUp(() => repo = MockProjectRepository());
  tearDown(() => repo.dispose());

  test('includes every project, squad and signal', () async {
    final snapshot = await repo.watch().first;
    final brief = SnapshotBrief.build(snapshot);

    for (final project in snapshot.projects) {
      expect(brief, contains(project.name));
    }
    for (final squad in snapshot.squads) {
      expect(brief, contains(squad.name));
    }
    for (final signal in snapshot.signals) {
      expect(brief, contains(signal.title));
    }
  });

  test('carries the reasoning, not just the numbers', () async {
    final snapshot = await repo.watch().first;
    final brief = SnapshotBrief.build(snapshot);

    // A score with no explanation would let the assistant repeat a number
    // without being able to say what drives it.
    for (final factor in snapshot.projects.first.factors) {
      expect(brief, contains(factor.detail));
    }
    for (final signal in snapshot.signals) {
      expect(brief, contains(signal.because));
    }
  });

  test('states that outage hours are excluded from scoring', () async {
    final snapshot = await repo.watch().first;
    final brief = SnapshotBrief.build(snapshot);

    // Without this the assistant could read lost hours as underdelivery,
    // which is the exact failure the research identifies in existing tools.
    expect(brief.toLowerCase(), contains('excluded'));
  });

  test('describes a trend in days, not as a list of states', () async {
    final snapshot = await repo.watch().first;
    final brief = SnapshotBrief.build(snapshot);

    // "Critical for 7 days" is what makes "how long has this been bad"
    // answerable; thirty state names in a row would not be.
    expect(brief, contains('Recent trend:'));
    expect(brief, matches(RegExp(r'for \d+ days')));
  });

  group('privacy', () {
    test('contains no individual identifier', () async {
      final snapshot = await repo.watch().first;
      final brief = SnapshotBrief.build(snapshot);

      // The domain model holds no per-person data, so there is nothing here
      // to leak. This asserts it rather than assuming it, and will fail if
      // someone later adds a member list to Squad and includes it.
      expect(brief, isNot(contains('@')));
      expect(brief.toLowerCase(), isNot(contains('developer ')));
      expect(brief.toLowerCase(), isNot(contains('assignee')));
      expect(brief.toLowerCase(), isNot(contains('author')));
    });

    test('squads report a headcount, never members', () async {
      final snapshot = await repo.watch().first;
      final brief = SnapshotBrief.build(snapshot);

      for (final squad in snapshot.squads) {
        expect(brief, contains('${squad.headcount} people'));
      }
    });
  });

  test('stays compact enough to re-send with every question', () async {
    final snapshot = await repo.watch().first;
    final brief = SnapshotBrief.build(snapshot);

    // The brief is sent on every turn, so its size is the running cost of the
    // feature. Roughly four characters per token, so this is about 2k tokens
    // for four projects — a sane ceiling to notice if it grows.
    expect(
      brief.length,
      lessThan(8000),
      reason: 'the brief is re-sent on every question; keep it lean',
    );
  });
}
