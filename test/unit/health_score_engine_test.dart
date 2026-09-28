import 'package:flutter_test/flutter_test.dart';

import 'package:keel/models/health_state.dart';
import 'package:keel/models/project_metrics.dart';
import 'package:keel/models/scoring_weights.dart';
import 'package:keel/services/health_scoring/health_score_engine.dart';

/// Builds metrics for a project doing well, with named overrides so each test
/// can change one thing and leave the rest healthy.
ProjectMetrics buildMetrics({
  String projectId = 'p1',
  int commitsInWindow = 40,
  double commitsBaseline = 40,
  int tasksCompletedInWindow = 20,
  double tasksCompletedBaseline = 20,
  double openIssueWeight = 50,
  double closedIssueWeight = 50,
  double budgetSpent = 50,
  double budgetTotal = 100,
  double scheduleElapsed = 0.5,
  double activeHours = 120,
  double availableHours = 120,
  double outageHours = 0,
}) {
  final now = DateTime(2026, 9, 27);
  return ProjectMetrics(
    projectId: projectId,
    windowStart: now.subtract(const Duration(days: 14)),
    windowEnd: now,
    commitsInWindow: commitsInWindow,
    commitsBaseline: commitsBaseline,
    tasksCompletedInWindow: tasksCompletedInWindow,
    tasksCompletedBaseline: tasksCompletedBaseline,
    openIssueWeight: openIssueWeight,
    closedIssueWeight: closedIssueWeight,
    budgetSpent: budgetSpent,
    budgetTotal: budgetTotal,
    scheduleElapsed: scheduleElapsed,
    activeHours: activeHours,
    availableHours: availableHours,
    outageHours: outageHours,
  );
}

void main() {
  final engine = HealthScoreEngine.standard();

  group('composite score', () {
    test('a project meeting every baseline scores as on track', () {
      final result = engine.score(metrics: buildMetrics());

      expect(result.state, HealthState.onTrack);
      expect(result.score, greaterThanOrEqualTo(75));
    });

    test('a project failing on every indicator scores as critical', () {
      final result = engine.score(
        metrics: buildMetrics(
          commitsInWindow: 4,
          tasksCompletedInWindow: 2,
          openIssueWeight: 200,
          closedIssueWeight: 20,
          budgetSpent: 95,
          scheduleElapsed: 0.3,
          activeHours: 30,
        ),
      );

      expect(result.state, HealthState.critical);
      expect(result.score, lessThan(35));
    });

    test('score always lands inside 0 to 100', () {
      final extreme = engine.score(
        metrics: buildMetrics(
          commitsInWindow: 100000,
          tasksCompletedInWindow: 100000,
          budgetSpent: 0,
          activeHours: 100000,
        ),
      );

      expect(extreme.score, inInclusiveRange(0, 100));
    });
  });

  group('breakdown', () {
    test('every factor is returned with the score', () {
      final result = engine.score(metrics: buildMetrics());

      // Five indicators, matching those named in the research proposal.
      expect(result.factors.length, 5);
      for (final factor in result.factors) {
        expect(
          factor.detail,
          isNotEmpty,
          reason: 'a factor without an explanation is not actionable',
        );
      }
    });

    test('weights are normalised so they sum to one', () {
      final result = engine.score(metrics: buildMetrics());

      final total = result.factors.fold<double>(0, (sum, f) => sum + f.weight);
      expect(total, closeTo(1.0, 0.001));
    });

    test('weights that do not sum to one are still normalised', () {
      // Settings are user-editable, so invalid weights have to be survivable.
      const lopsided = ScoringWeights(
        budgetBurn: 2,
        taskVelocity: 2,
        issueComplexity: 2,
        commitVolume: 2,
        idleTime: 2,
      );

      final result = engine.score(metrics: buildMetrics(), weights: lopsided);

      final total = result.factors.fold<double>(0, (sum, f) => sum + f.weight);
      expect(total, closeTo(1.0, 0.001));
      expect(result.score, inInclusiveRange(0, 100));
    });
  });

  group('anti-gaming', () {
    test('inflating one indicator cannot rescue a failing project', () {
      // A team that responds to being measured by making hundreds of trivial
      // commits, while everything else keeps sliding. The Hawthorne effect
      // the research proposal raises, expressed as a test.
      final gamed = engine.score(
        metrics: buildMetrics(
          commitsInWindow: 5000,
          tasksCompletedInWindow: 2,
          openIssueWeight: 200,
          closedIssueWeight: 20,
          budgetSpent: 95,
          scheduleElapsed: 0.3,
          activeHours: 30,
        ),
      );

      expect(
        gamed.state.severity,
        greaterThanOrEqualTo(HealthState.atRisk.severity),
        reason: 'commit volume is weighted lowest precisely so this fails',
      );
    });
  });

  group('load-shedding', () {
    test('outage hours do not reduce the score', () {
      // Same work done, but half the rostered time was lost to outages. The
      // team did as well as it could with the time it had.
      final withoutOutage = engine.score(
        metrics: buildMetrics(activeHours: 60, availableHours: 60),
      );

      final withOutage = engine.score(
        metrics: buildMetrics(
          activeHours: 60,
          availableHours: 120,
          outageHours: 60,
        ),
      );

      expect(
        withOutage.score,
        closeTo(withoutOutage.score, 0.001),
        reason: 'a team must never be scored down for a power failure',
      );
    });

    test('a window lost entirely to outages does not score zero', () {
      final result = engine.score(
        metrics: buildMetrics(
          activeHours: 0,
          availableHours: 120,
          outageHours: 120,
        ),
      );

      final idle = result.factors.firstWhere(
        (f) => f.name == 'Idle-time ratio',
      );
      expect(
        idle.value,
        greaterThan(50),
        reason: 'a blackout is not a failing team',
      );
    });
  });
}
