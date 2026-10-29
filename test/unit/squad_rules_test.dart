import 'package:flutter_test/flutter_test.dart';

import 'package:prahm/models/squad.dart';
import 'package:prahm/models/squad_rules.dart';

/// What may be saved when a squad is created or renamed.
///
/// These rules exist in three places: here, on the form, and in
/// `firestore.rules`. The limits below are the ones the rules repeat, so a
/// change here that is not made there would be accepted by the app and
/// refused by the backend.
void main() {
  group('a squad name', () {
    test('is required', () {
      expect(SquadRules.nameProblem(''), isNotNull);
      expect(SquadRules.nameProblem('   '), isNotNull);
    });

    test('is accepted once it says something', () {
      expect(SquadRules.nameProblem('Platform'), isNull);
    });

    test('is accepted at the limit and refused past it', () {
      // The boundary rather than a round number, because this is the figure
      // `firestore.rules` repeats.
      expect(SquadRules.nameProblem('a' * SquadRules.maxName), isNull);
      expect(SquadRules.nameProblem('a' * (SquadRules.maxName + 1)), isNotNull);
    });

    test('is measured after trimming, so spaces cannot pad it past the limit', () {
      final padded = '  ${'a' * SquadRules.maxName}  ';

      expect(SquadRules.nameProblem(padded), isNull);
    });
  });

  group('a stated headcount', () {
    test('may be left unstated, which reads as zero', () {
      // Not every squad knows its own number, and refusing to save without
      // one would make the squad unnameable for the sake of a figure
      // ingestion does not use.
      expect(SquadRules.headcountProblem(''), isNull);
      expect(SquadRules.parseHeadcount(''), 0);
    });

    test('must be a whole number', () {
      expect(SquadRules.headcountProblem('four'), isNotNull);
      expect(SquadRules.headcountProblem('4.5'), isNotNull);
    });

    test('cannot be negative', () {
      expect(SquadRules.headcountProblem('-1'), isNotNull);
    });

    test('is accepted at the limit and refused past it', () {
      expect(SquadRules.headcountProblem('${SquadRules.maxHeadcount}'), isNull);
      expect(
        SquadRules.headcountProblem('${SquadRules.maxHeadcount + 1}'),
        isNotNull,
      );
    });

    test('parses a stated number', () {
      expect(SquadRules.parseHeadcount(' 7 '), 7);
    });
  });

  group('two squads with the same name', () {
    const existing = [
      Squad(
        id: 's1',
        name: 'Platform',
        headcount: 4,
        capacityUsed: 0,
        activeProjectCount: 0,
        velocityTrend: 0,
      ),
      Squad(
        id: 's2',
        name: 'Mobile',
        headcount: 3,
        capacityUsed: 0,
        activeProjectCount: 0,
        velocityTrend: 0,
      ),
    ];

    test('are caught regardless of capitals or surrounding spaces', () {
      // Two squads a person cannot tell apart on screen are worse than a
      // refusal, because every later decision about either one is ambiguous.
      expect(SquadRules.nameTaken('platform', existing), isTrue);
      expect(SquadRules.nameTaken('  PLATFORM  ', existing), isTrue);
    });

    test('do not block a genuinely new name', () {
      expect(SquadRules.nameTaken('Data', existing), isFalse);
    });

    test('do not stop a squad keeping its own name while being renamed', () {
      // Editing a squad and saving without touching the name must work, or
      // the headcount could never be changed on its own.
      expect(
        SquadRules.nameTaken('Platform', existing, exceptId: 's1'),
        isFalse,
      );
      expect(
        SquadRules.nameTaken('Platform', existing, exceptId: 's2'),
        isTrue,
      );
    });
  });
}
