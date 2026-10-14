import 'package:test/test.dart';

import 'package:keel/models/outage_window.dart';
import 'package:keel/models/project_plan.dart';
import 'package:keel/models/squad_activity.dart';
import 'package:keel/services/health_scoring/factor_calculators/idle_time_calculator.dart';
import 'package:keel/services/ingestion/metrics_assembler.dart';

/// Idle time is measured over a rolling week rather than over the poll window.
///
/// The reason is the whole point of this file. Ingestion runs every six hours,
/// which means most runs happen while the team is asleep. Measured over the
/// window, an overnight run finds no activity against a sixth of a week's
/// roster and reports a squad as idle — four times a day, for the entirely
/// normal act of not working at 3am.
///
/// A score that drops overnight and recovers by lunchtime is noise, and noise
/// in an early-warning system is how people learn to ignore it.
void main() {
  const assembler = MetricsAssembler();
  const calculator = IdleTimeCalculator();

  final now = DateTime.utc(2026, 10, 14, 3); // an overnight run

  const plan = ProjectPlan(
    projectId: 'p1',
    budgetTotal: 100000,
    budgetSpent: 40000,
    weeklyHours: 120,
  );

  SquadActivity window({
    required DateTime end,
    required int activePersonHours,
    int tasks = 2,
  }) {
    return SquadActivity(
      squadId: 's1',
      windowStart: end.subtract(const Duration(hours: 6)),
      windowEnd: end,
      commitCount: activePersonHours,
      tasksCompleted: tasks,
      tasksOpened: 0,
      closedIssueWeight: tasks.toDouble(),
      openIssueWeight: 4,
      contributorCount: 2,
      activePersonHours: activePersonHours,
    );
  }

  test('a quiet overnight window does not read as an idle squad', () {
    // Nothing happened in the last six hours, because it is 3am. But the week
    // behind it holds 90 person-hours of work.
    final history = [
      for (var i = 1; i <= 20; i++)
        window(
          end: now.subtract(Duration(hours: 6 * i)),
          activePersonHours: i <= 18 ? 5 : 0,
        ),
    ];

    final metrics = assembler.assemble(
      projectId: 'p1',
      activity: window(end: now, activePersonHours: 0),
      plan: plan,
      history: history,
      outages: const [],
      now: now,
    );

    final result = calculator.calculate(metrics);

    expect(metrics.activeHours, greaterThan(0));
    expect(
      result.value,
      greaterThan(50),
      reason: 'a sleeping team is not an idle one',
    );
  });

  test('a genuinely idle week does read as idle', () {
    // The guard above must not swallow the signal it exists to protect. A
    // week with almost no activity should still score badly.
    final history = [
      for (var i = 1; i <= 20; i++)
        window(
          end: now.subtract(Duration(hours: 6 * i)),
          activePersonHours: 0,
          tasks: 0,
        ),
    ];

    final metrics = assembler.assemble(
      projectId: 'p1',
      activity: window(end: now, activePersonHours: 1, tasks: 0),
      plan: plan,
      history: history,
      outages: const [],
      now: now,
    );

    expect(calculator.calculate(metrics).value, lessThan(40));
  });

  test('windows older than the week are not counted', () {
    // Two weeks of solid work, but only the last week is the question being
    // asked. Counting it all would let a good fortnight hide a bad week.
    final history = [
      for (var i = 1; i <= 50; i++)
        window(end: now.subtract(Duration(hours: 6 * i)), activePersonHours: 5),
    ];

    final metrics = assembler.assemble(
      projectId: 'p1',
      activity: window(end: now, activePersonHours: 5),
      plan: plan,
      history: history,
      outages: const [],
      now: now,
    );

    // 28 windows of 5 would be 140, past the 120-hour roster. Capped at the
    // workable hours, because a roster overrun is Squad.capacityUsed's
    // business, not this indicator's.
    expect(metrics.activeHours, lessThanOrEqualTo(metrics.workableHours));
  });

  test('outage hours still come out of the denominator, not the score', () {
    final history = [
      for (var i = 1; i <= 20; i++)
        window(end: now.subtract(Duration(hours: 6 * i)), activePersonHours: 3),
    ];

    final withoutOutage = assembler.assemble(
      projectId: 'p1',
      activity: window(end: now, activePersonHours: 3),
      plan: plan,
      history: history,
      outages: const [],
      now: now,
    );

    final withOutage = assembler.assemble(
      projectId: 'p1',
      activity: window(end: now, activePersonHours: 3),
      plan: plan,
      history: history,
      outages: [
        OutageWindow(
          id: 'out-1',
          stage: 4,
          start: now.subtract(const Duration(days: 2, hours: 8)),
          end: now.subtract(const Duration(days: 2)),
          affectedSquadIds: const ['s1'],
        ),
      ],
      now: now,
    );

    // Constraint 2: the hours are removed from what the team had, so the
    // same work over fewer workable hours scores better, never worse.
    expect(withOutage.workableHours, lessThan(withoutOutage.workableHours));
    expect(
      calculator.calculate(withOutage).value,
      greaterThanOrEqualTo(calculator.calculate(withoutOutage).value),
    );
  });
}
