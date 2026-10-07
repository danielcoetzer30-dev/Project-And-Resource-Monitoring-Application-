import 'package:flutter_test/flutter_test.dart';

import 'package:keel/models/project.dart';
import 'package:keel/services/health_scoring/forecaster.dart';

/// A project with everything healthy, so each test can change one thing.
Project build({
  double budgetBurn = 0.5,
  int scheduleDaysRemaining = 45,
  int scheduleTotalDays = 90,
  double velocityRatio = 1.0,
}) {
  return Project(
    id: 'p1',
    name: 'Test project',
    client: 'Test client',
    squadId: 's1',
    score: 70,
    factors: const [],
    seam: const [],
    openSignals: 0,
    budgetBurn: budgetBurn,
    scheduleDaysRemaining: scheduleDaysRemaining,
    scheduleTotalDays: scheduleTotalDays,
    velocityRatio: velocityRatio,
    loadSheddingHoursLost: 0,
  );
}

void main() {
  const forecaster = Forecaster();

  group('budget runway', () {
    test('spending exactly to plan runs out exactly as scope closes', () {
      // Half the money, half the time. 45 days of budget, 45 days of work.
      final f = forecaster.project(build());

      expect(f.budgetRunsOutInDays, 45);
      expect(f.budgetShortfallDays, 0);
      expect(f.hasBudgetWarning, isFalse);
    });

    test('overspending runs the money out first', () {
      // 94% spent with 79 of 90 days gone, 11 days of scope left.
      final f = forecaster.project(
        build(
          budgetBurn: 0.94,
          scheduleDaysRemaining: 11,
          scheduleTotalDays: 90,
        ),
      );

      // 0.94 over 79 days is ~0.0119 a day; 0.06 left lasts about 5 days.
      expect(f.budgetRunsOutInDays, 5);
      expect(f.budgetShortfallDays, 6);
      expect(f.hasBudgetWarning, isTrue);
    });

    test('underspending leaves money over, and warns about nothing', () {
      final f = forecaster.project(
        build(budgetBurn: 0.3, scheduleDaysRemaining: 45),
      );

      expect(f.budgetShortfallDays, lessThan(0));
      expect(f.hasBudgetWarning, isFalse);
    });

    test('a budget already spent reports zero days, not a negative', () {
      final f = forecaster.project(build(budgetBurn: 1.0));

      expect(f.budgetRunsOutInDays, 0);
      expect(f.hasBudgetWarning, isTrue);
    });
  });

  group('schedule projection', () {
    test('working at baseline finishes on time', () {
      final f = forecaster.project(build(velocityRatio: 1.0));

      expect(f.projectedCompletionDays, 45);
      expect(f.projectedOverrunDays, 0);
      expect(f.hasScheduleWarning, isFalse);
    });

    test('running slow pushes the end date out', () {
      // At 62% of baseline, 45 days of work takes about 73.
      final f = forecaster.project(build(velocityRatio: 0.62));

      expect(f.projectedCompletionDays, 73);
      expect(f.projectedOverrunDays, 28);
      expect(f.hasScheduleWarning, isTrue);
    });

    test('running fast pulls it in', () {
      final f = forecaster.project(build(velocityRatio: 1.25));

      expect(f.projectedOverrunDays, lessThan(0));
      expect(f.hasScheduleWarning, isFalse);
    });
  });

  group('refuses to guess', () {
    test('no schedule total means no budget forecast', () {
      // An old Firestore document written before the field existed.
      final f = forecaster.project(build(scheduleTotalDays: 0));

      expect(f.budgetRunsOutInDays, isNull);
      expect(f.budgetShortfallDays, isNull);
    });

    test('a project that has not started yet produces no budget forecast', () {
      // Nothing elapsed, so there is no rate to project from.
      final f = forecaster.project(
        build(scheduleTotalDays: 90, scheduleDaysRemaining: 90),
      );

      expect(f.budgetRunsOutInDays, isNull);
    });

    test('a stalled squad produces no date rather than an absurd one', () {
      // At 2% of baseline the arithmetic says fifty years. Reporting that
      // would discredit every other number on the screen.
      final f = forecaster.project(build(velocityRatio: 0.02));

      expect(f.projectedCompletionDays, isNull);
      expect(f.hasScheduleWarning, isFalse);
    });

    test('a finished project projects nothing', () {
      final f = forecaster.project(build(scheduleDaysRemaining: 0));

      expect(f.projectedCompletionDays, isNull);
    });

    test('no information at all reports empty, not zero', () {
      final f = forecaster.project(
        build(scheduleTotalDays: 0, scheduleDaysRemaining: 0),
      );

      expect(f.isEmpty, isTrue);
    });
  });

  group('headline', () {
    test('names both problems when both are present', () {
      final project = build(
        budgetBurn: 0.94,
        scheduleDaysRemaining: 11,
        scheduleTotalDays: 90,
        velocityRatio: 0.62,
      );
      final headline = forecaster.headline(project);

      expect(headline, contains('budget runs out'));
      expect(headline, contains('late'));
    });

    test('says nothing when there is nothing to warn about', () {
      expect(forecaster.headline(build()), isNull);
    });

    test('reads as a projection, not a certainty', () {
      final headline = forecaster.headline(
        build(budgetBurn: 0.94, scheduleDaysRemaining: 11),
      );

      // The wording matters: a team will plan around this number.
      expect(headline, contains('At the current rate'));
    });
  });
}
