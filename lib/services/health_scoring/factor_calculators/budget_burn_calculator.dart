import '../../../models/project_metrics.dart';
import '../../../models/scoring_weights.dart';
import '../factor_calculator.dart';

/// Spend rate measured against how much of the schedule has passed.
///
/// Burn on its own says nothing — 60% spent is healthy at 60% elapsed and
/// alarming at 20%. What matters is the gap between the two, which is the
/// earliest visible sign of a project that will run out of money before it
/// runs out of scope.
class BudgetBurnCalculator implements FactorCalculator {
  const BudgetBurnCalculator();

  @override
  String get name => 'Budget burn';

  @override
  double weightFrom(ScoringWeights weights) => weights.budgetBurn;

  @override
  FactorResult calculate(ProjectMetrics metrics) {
    if (metrics.budgetTotal <= 0) {
      return const FactorResult(
        value: 60,
        detail: 'No budget recorded for this project',
      );
    }

    final burn = metrics.budgetBurn;
    final elapsed = metrics.scheduleElapsed;
    final burnPercent = (burn * 100).round();
    final elapsedPercent = (elapsed * 100).round();

    // Spending ahead of schedule is the risk. Each point of overspend costs
    // more than a point of underspend gains, because a project cannot be
    // rescued by having money left over at the end.
    final gap = burn - elapsed;
    final value = gap <= 0
        ? clampScore(85 + gap.abs() * 30)
        : clampScore(85 - gap * 200);

    final detail = switch (gap) {
      > 0.15 =>
        '$burnPercent% of budget spent against $elapsedPercent% of the schedule — spending well ahead of plan',
      > 0.05 =>
        '$burnPercent% spent against $elapsedPercent% elapsed — slightly ahead of plan',
      < -0.05 =>
        '$burnPercent% spent against $elapsedPercent% elapsed — under plan',
      _ =>
        '$burnPercent% spent against $elapsedPercent% elapsed — tracking to plan',
    };

    return FactorResult(value: value, detail: detail);
  }
}
