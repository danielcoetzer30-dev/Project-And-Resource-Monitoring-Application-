import 'package:test/test.dart';

import 'package:prahm/models/outage_window.dart';
import 'package:prahm/models/project_plan.dart';
import 'package:prahm/models/squad_activity.dart';
import 'package:prahm/services/health_scoring/factor_calculators/idle_time_calculator.dart';
import 'package:prahm/services/ingestion/metrics_assembler.dart';

/// Idle time asks "what did they do with the time they had", so the hours
/// worked and the hours available must cover the same period.
///
/// They have not always. Scoring a six-hour window against a sixth of a week's
/// roster reported a squad as idle overnight, four times a day, for the
/// entirely normal act of being asleep. The window is a week now, which fixes
/// that by construction — and introduces the opposite trap, which these tests
/// are mostly here to hold shut.
void main() {
  const assembler = MetricsAssembler();
  const calculator = IdleTimeCalculator();

  final now = DateTime.utc(2026, 10, 19, 6);

  const plan = ProjectPlan(
    projectId: 'p1',
    budgetTotal: 100000,
    budgetSpent: 40000,
    weeklyHours: 120,
  );

  /// A seven-day window ending at [end].
  SquadActivity week({
    required DateTime end,
    required int activePersonHours,
    int tasks = 10,
  }) {
    return SquadActivity(
      squadId: 's1',
      windowStart: end.subtract(const Duration(days: 7)),
      windowEnd: end,
      commitCount: activePersonHours,
      tasksCompleted: tasks,
      tasksOpened: 2,
      closedIssueWeight: tasks.toDouble(),
      openIssueWeight: 20,
      contributorCount: 3,
      activePersonHours: activePersonHours,
    );
  }

  test('a week of work is measured against a week of roster', () {
    final metrics = assembler.assemble(
      projectId: 'p1',
      activity: week(end: now, activePersonHours: 60),
      plan: plan,
      history: const [],
      outages: const [],
      now: now,
    );

    expect(metrics.availableHours, closeTo(120, 0.001));
    expect(metrics.activeHours, closeTo(60, 0.001));
    expect(calculator.calculate(metrics).detail, contains('50%'));
  });

  test('overlapping stored windows are never added together', () {
    // The trap. Runs are daily and each covers seven days, so yesterday's
    // stored window shares six of them with today's. Summing the ones inside
    // the last week — which is what this did when a run covered six hours —
    // would report about seven times the work actually done, and every squad
    // would look fully utilised forever.
    final history = [
      for (var day = 1; day <= 10; day++)
        week(end: now.subtract(Duration(days: day)), activePersonHours: 60),
    ];

    final metrics = assembler.assemble(
      projectId: 'p1',
      activity: week(end: now, activePersonHours: 60),
      plan: plan,
      history: history,
      outages: const [],
      now: now,
    );

    expect(
      metrics.activeHours,
      closeTo(60, 0.001),
      reason: 'only this window counts, not the overlapping ones behind it',
    );
  });

  test('a short window scales the roster down with it', () {
    // A half-week window has half a week of capacity. Otherwise a run with a
    // shorter window reads as a team that stopped working.
    final metrics = assembler.assemble(
      projectId: 'p1',
      activity: SquadActivity(
        squadId: 's1',
        windowStart: now.subtract(const Duration(days: 3, hours: 12)),
        windowEnd: now,
        commitCount: 30,
        tasksCompleted: 5,
        tasksOpened: 1,
        closedIssueWeight: 5,
        openIssueWeight: 20,
        contributorCount: 3,
        activePersonHours: 30,
      ),
      plan: plan,
      history: const [],
      outages: const [],
      now: now,
    );

    expect(metrics.availableHours, closeTo(60, 0.001));
    expect(calculator.calculate(metrics).detail, contains('50%'));
  });

  test('a genuinely idle week still reads as idle', () {
    // The guard above must not swallow the signal it exists to protect.
    final metrics = assembler.assemble(
      projectId: 'p1',
      activity: week(end: now, activePersonHours: 2, tasks: 0),
      plan: plan,
      history: const [],
      outages: const [],
      now: now,
    );

    expect(calculator.calculate(metrics).value, lessThan(40));
  });

  test('outage hours come out of the denominator, not off the score', () {
    final activity = week(end: now, activePersonHours: 60);

    final clear = assembler.assemble(
      projectId: 'p1',
      activity: activity,
      plan: plan,
      history: const [],
      outages: const [],
      now: now,
    );

    final shed = assembler.assemble(
      projectId: 'p1',
      activity: activity,
      plan: plan,
      history: const [],
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

    // Constraint 2: the hours are taken off what the team had, so the same
    // work over fewer workable hours scores better and never worse.
    expect(shed.outageHours, closeTo(8, 0.001));
    expect(shed.workableHours, lessThan(clear.workableHours));
    expect(
      calculator.calculate(shed).value,
      greaterThan(calculator.calculate(clear).value),
    );
  });

  test('a week lost entirely to outages is not scored at all', () {
    final metrics = assembler.assemble(
      projectId: 'p1',
      activity: week(end: now, activePersonHours: 0, tasks: 0),
      plan: plan,
      history: const [],
      outages: [
        OutageWindow(
          id: 'out-1',
          stage: 6,
          start: now.subtract(const Duration(days: 7)),
          end: now,
          affectedSquadIds: const ['s1'],
        ),
      ],
      now: now,
    );

    // A blackout is not a failing team, so this reports the neutral middle
    // rather than zero.
    expect(metrics.workableHours, 0);
    expect(calculator.calculate(metrics).value, 60);
  });
}
