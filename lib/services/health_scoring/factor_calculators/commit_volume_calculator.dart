import '../../../models/project_metrics.dart';
import '../../../models/scoring_weights.dart';
import '../factor_calculator.dart';

/// Commit activity against the squad's own recent baseline.
///
/// Weighted lowest of the five on purpose. Commit count is the easiest
/// indicator to game — a developer who knows they are measured on it can
/// produce a dozen trivial commits in a minute — so it contributes least and
/// only ever alongside four others. That is the whole reason the score is a
/// matrix rather than a single number.
///
/// Counted per squad, never per person.
class CommitVolumeCalculator implements FactorCalculator {
  const CommitVolumeCalculator();

  @override
  String get name => 'Commit volume';

  @override
  double weightFrom(ScoringWeights weights) => weights.commitVolume;

  @override
  FactorResult calculate(ProjectMetrics metrics) {
    if (metrics.commitsBaseline <= 0) {
      return const FactorResult(
        value: 60,
        detail: 'Not enough history yet to compare commit activity',
      );
    }

    final ratio = metrics.commitsInWindow / metrics.commitsBaseline;
    final value = scoreFromRatio(ratio);
    final changePercent = ((ratio - 1) * 100).round();

    final detail = switch (changePercent) {
      < -20 =>
        'Commit activity down ${changePercent.abs()}% on this squad\'s baseline',
      < -5 =>
        'Commit activity slightly down, ${changePercent.abs()}% below baseline',
      > 5 => 'Commit activity up $changePercent% on baseline',
      _ => 'Commit activity steady against baseline',
    };

    return FactorResult(value: value, detail: detail);
  }
}
