import 'package:flutter_test/flutter_test.dart';

import 'package:prahm/models/activity_event.dart';
import 'package:prahm/services/ingestion/anonymiser.dart';

/// These tests are the ethics commitment made executable.
///
/// Section D of the research proposal promises a system built without
/// individual identity. If someone later changes the anonymiser in a way that
/// lets an author key reach the output, these fail, which is the point.
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
      // author key. Deliberately crude, it would catch an identifier smuggled
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

  group('a source can stand in for naming people', () {
    const bySource = Anonymiser(squadOfSource: {'src1': 's1'});

    test('every contributor to a source counts towards its squad', () {
      final result = bySource.anonymise(
        events: [
          event(author: 'nobody-has-listed-me.com'),
          event(author: 'nor-me.com'),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      // Neither author appears in any configuration, and the aggregate is
      // still built. That is the point: one fewer place identity is written
      // down, with no loss of what the scoring needs.
      expect(result.single.squadId, 's1');
      expect(result.single.contributorCount, 2);
    });

    test('the threshold still holds when nobody is named', () {
      // The protection must not weaken because the configuration got
      // simpler. Contributors are counted from the events themselves.
      final result = bySource.anonymise(
        events: [event(author: 'alone.com')],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(result, isEmpty);
    });

    test('a per-person mapping still wins where one exists', () {
      // A shared repository can be split between squads: the author mapping
      // is consulted first, the source only decides what it does not cover.
      const split = Anonymiser(
        squadOfAuthor: {'diego@example.com': 's2', 'daniele@example.com': 's2'},
        squadOfSource: {'src1': 's1'},
      );

      final result = split.anonymise(
        events: [
          event(author: 'diego@example.com'),
          event(author: 'daniele@example.com'),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(result.single.squadId, 's2');
    });

    test('an event from an unmapped source is discarded', () {
      final result = const Anonymiser().anonymise(
        events: [
          event(author: 'a@example.com'),
          event(author: 'b@example.com'),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(result, isEmpty);
    });
  });

  group('active person-hours', () {
    test('counts an hour once per person, however busy they were', () {
      // Three commits from one person inside the same hour is one hour of
      // that person working, not three. Counting events would make a
      // utilisation figure out of commit frequency, which is the thing the
      // scoring is careful not to reward.
      final result = anonymiser.anonymise(
        events: [
          event(author: 'diego@example.com', at: DateTime(2026, 9, 15, 9, 5)),
          event(author: 'diego@example.com', at: DateTime(2026, 9, 15, 9, 40)),
          event(author: 'diego@example.com', at: DateTime(2026, 9, 15, 9, 55)),
          event(
            author: 'daniele@example.com',
            at: DateTime(2026, 9, 15, 9, 10),
          ),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      // One hour for each of two people.
      expect(result.single.activePersonHours, 2);
    });

    test('two people in different hours is two person-hours', () {
      final result = anonymiser.anonymise(
        events: [
          event(author: 'diego@example.com', at: DateTime(2026, 9, 15, 9)),
          event(author: 'daniele@example.com', at: DateTime(2026, 9, 15, 14)),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(result.single.activePersonHours, 2);
    });

    test('one person across four hours is four person-hours', () {
      final result = anonymiser.anonymise(
        events: [
          for (final hour in [9, 10, 11, 12])
            event(author: 'diego@example.com', at: DateTime(2026, 9, 15, hour)),
          // A second contributor, or the squad would be suppressed and there
          // would be nothing to assert on.
          event(author: 'daniele@example.com', at: DateTime(2026, 9, 15, 9)),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(result.single.activePersonHours, 5);
    });

    test('a suppressed squad reports no hours at all', () {
      // The hours of a one-person squad are one person's working pattern,
      // which is exactly what the threshold exists to withhold.
      final result = anonymiser.anonymise(
        events: [
          for (final hour in [9, 10, 11])
            event(author: 'diego@example.com', at: DateTime(2026, 9, 15, hour)),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      expect(result, isEmpty);
    });

    test('the figure that leaves is a number, not a pattern', () {
      final result = anonymiser.anonymise(
        events: [
          event(author: 'diego@example.com', at: DateTime(2026, 9, 15, 9)),
          event(author: 'daniele@example.com', at: DateTime(2026, 9, 15, 22)),
        ],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      final activity = result.single;

      // 9am and 10pm went in; a 2 comes out. Nothing downstream can tell who
      // worked, or when, or that anybody worked late.
      expect(activity.activePersonHours, 2);
      expect(activity.toString(), isNot(contains('diego')));
      expect(activity.toString(), isNot(contains('22')));
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
