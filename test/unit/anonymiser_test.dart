import 'package:flutter_test/flutter_test.dart';

import 'package:keel/models/activity_event.dart';
import 'package:keel/services/ingestion/anonymiser.dart';

/// These tests are the ethics commitment made executable.
///
/// Section D of the research proposal promises a system built without
/// individual identity. If someone later changes the anonymiser in a way that
/// lets an author key reach the output, these fail — which is the point.
void main() {
  final windowStart = DateTime(2026, 9, 1);
  final windowEnd = DateTime(2026, 9, 30);

  RawActivityEvent event({
    required String author,
    ActivityType type = ActivityType.commit,
    double weight = 1,
    DateTime? at,
  }) {
    return RawActivityEvent(
      sourceId: 'src1',
      authorKey: author,
      occurredAt: at ?? DateTime(2026, 9, 15),
      type: type,
      weight: weight,
    );
  }

  const anonymiser = Anonymiser(
    squadOfAuthor: {
      'diego@example.com': 's1',
      'daniele@example.com': 's1',
      'tristen@example.com': 's1',
      'sya@example.com': 's2',
      'daniel@example.com': 's2',
    },
  );

  group('identity never survives', () {
    test('no author key appears anywhere in the output', () {
      final results = anonymiser.anonymise(
        events: [
          event(author: 'diego@example.com'),
          event(author: 'daniele@example.com'),
          event(author: 'tristen@example.com'),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(results, isNotEmpty);

      // Every field of every result, rendered as text, must not contain any
      // author key. Deliberately crude — it would catch an identifier smuggled
      // into a squad id or any other string field.
      for (final activity in results) {
        final rendered = [
          activity.squadId,
          activity.commitCount.toString(),
          activity.tasksCompleted.toString(),
          activity.tasksOpened.toString(),
          activity.closedIssueWeight.toString(),
          activity.openIssueWeight.toString(),
          activity.contributorCount.toString(),
        ].join(' ');

        for (final author in anonymiser.squadOfAuthor.keys) {
          expect(
            rendered.contains(author),
            isFalse,
            reason: 'author key leaked into squad output',
          );
        }
      }
    });

    test('output exposes a contributor count, never contributors', () {
      final results = anonymiser.anonymise(
        events: [
          event(author: 'diego@example.com'),
          event(author: 'daniele@example.com'),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(results.single.contributorCount, 2);
      // SquadActivity has no field holding a collection of people. If one is
      // ever added, this test should be updated to forbid it explicitly.
    });
  });

  group('minimum contributor threshold', () {
    test('a squad with one contributor is suppressed entirely', () {
      final results = anonymiser.anonymise(
        events: [
          // s2 has only one person active in this window.
          event(author: 'sya@example.com'),
          event(author: 'sya@example.com'),
          event(author: 'sya@example.com'),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(
        results,
        isEmpty,
        reason: 'a one-person "squad total" is individual activity relabelled',
      );
    });

    test('suppressed squads are reported as ids only', () {
      final suppressed = anonymiser.suppressedSquads(
        events: [event(author: 'sya@example.com')],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(suppressed, ['s2']);
    });

    test('a squad meeting the threshold is reported', () {
      final results = anonymiser.anonymise(
        events: [
          event(author: 'sya@example.com'),
          event(author: 'daniel@example.com'),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(results.single.squadId, 's2');
      expect(results.single.commitCount, 2);
    });
  });

  group('aggregation', () {
    test('unmapped authors are discarded, not bucketed', () {
      final results = anonymiser.anonymise(
        events: [
          event(author: 'stranger@example.com'),
          event(author: 'another@example.com'),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(
        results,
        isEmpty,
        reason: 'an "unknown" bucket is often one identifiable person',
      );
    });

    test('events outside the window are ignored', () {
      final results = anonymiser.anonymise(
        events: [
          event(author: 'diego@example.com', at: DateTime(2026, 8, 1)),
          event(author: 'daniele@example.com', at: DateTime(2026, 10, 15)),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(results, isEmpty);
    });

    test('task weights sum per squad', () {
      final results = anonymiser.anonymise(
        events: [
          event(
            author: 'diego@example.com',
            type: ActivityType.taskCompleted,
            weight: 3,
          ),
          event(
            author: 'daniele@example.com',
            type: ActivityType.taskCompleted,
            weight: 5,
          ),
          event(
            author: 'tristen@example.com',
            type: ActivityType.taskOpened,
            weight: 8,
          ),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      final s1 = results.single;
      expect(s1.tasksCompleted, 2);
      expect(s1.closedIssueWeight, 8);
      expect(s1.tasksOpened, 1);
      expect(s1.openIssueWeight, 8);
      expect(s1.contributorCount, 3);
    });
  });
}
