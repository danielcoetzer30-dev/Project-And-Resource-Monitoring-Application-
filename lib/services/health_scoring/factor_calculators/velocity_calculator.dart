import '../../../models/project_metrics.dart';
import '../../../models/scoring_weights.dart';
import '../factor_calculator.dart';

/// Task throughput against the squad's own recent baseline.
///
/// Compared against itself rather than any industry figure. A three-person
/// team in Durban and a twelve-person team in Cape Town have no business being
/// held to the same number, and the research is explicit that context-blind
/// benchmarks are part of why existing tools fail small South African teams.
class VelocityCalculator implements FactorCalculator {
  const VelocityCalculator();

  @override
  String get name => 'Task velocity';

  @override
  double weightFrom(ScoringWeights weights) => weights.taskVelocity;

  @override
  FactorResult calculate(ProjectMetrics metrics) {
    // No baseline yet means the project is too new to judge. Report the
    // neutral middle rather than inventing a verdict from one window.
    if (metrics.tasksCompletedBaseline <= 0) {
      return const FactorResult(
        value: 60,
        detail: 'Not enough history yet to compare against a baseline',
      );
    }

    final ratio =
        metrics.tasksCompletedInWindow / metrics.tasksCompletedBaseline;
    final value = scoreFromRatio(ratio);
    final changePercent = ((ratio - 1) * 100).round();

    final detail = switch (changePercent) {
      < -5 =>
        'Throughput down ${changePercent.abs()}% against this squad\'s own baseline',
      > 5 => 'Throughput up $changePercent% against this squad\'s own baseline',
      _ => 'Throughput steady against this squad\'s own baseline',
    };

    return FactorResult(value: value, detail: detail);
  }
}
