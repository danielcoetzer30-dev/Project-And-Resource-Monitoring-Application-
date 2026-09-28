import '../../../models/project_metrics.dart';
import '../../../models/scoring_weights.dart';
import '../factor_calculator.dart';

/// How much of the squad's workable time was actually productive.
///
/// This is the calculator the whole load-shedding argument rests on. Outage
/// hours are removed from the denominator *before* the ratio is taken, so the
/// question being asked is "what did they do with the time they had", never
/// "why were they not working during a national blackout".
///
/// Getting this the wrong way round would reproduce exactly the failure the
/// research identifies in existing tools: infrastructure collapse read as
/// underdelivery, and a team penalised for something entirely outside its
/// control.
class IdleTimeCalculator implements FactorCalculator {
  const IdleTimeCalculator();

  @override
  String get name => 'Idle-time ratio';

  @override
  double weightFrom(ScoringWeights weights) => weights.idleTime;

  @override
  FactorResult calculate(ProjectMetrics metrics) {
    // workableHours has already had outage time subtracted.
    final workable = metrics.workableHours;

    if (workable <= 0) {
      // The entire window was lost to outages. There is no performance to
      // measure, so report neutral rather than zero — a blackout is not a
      // failing team.
      return FactorResult(
        value: 60,
        detail:
            'Whole window lost to outages (${metrics.outageHours.toStringAsFixed(1)}h). Nothing scored against this project.',
      );
    }

    final utilisation = metrics.activeHours / workable;
    final value = scoreFromRatio(utilisation);
    final utilPercent = (utilisation * 100).round();

    final outageNote = metrics.outageHours > 0
        ? ' ${metrics.outageHours.toStringAsFixed(1)} hours lost to outages, excluded from this score.'
        : '';

    final detail = switch (utilisation) {
      < 0.6 => 'Only $utilPercent% of workable time was active.$outageNote',
      < 0.85 => '$utilPercent% of workable time was active.$outageNote',
      _ => 'Strong use of workable time at $utilPercent%.$outageNote',
    };

    return FactorResult(value: value, detail: detail);
  }
}
