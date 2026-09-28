import '../../../models/project_metrics.dart';
import '../../../models/scoring_weights.dart';
import '../factor_calculator.dart';

/// Whether the work still to do is getting harder.
///
/// Teams under pressure clear the easy items first, which makes a burndown
/// chart look healthy right up until it stalls. Comparing the weight of what
/// remains against the weight of what was cleared catches that: if the open
/// pile is getting heavier while throughput holds steady, the difficult work
/// is being deferred rather than done.
class ComplexityRatioCalculator implements FactorCalculator {
  const ComplexityRatioCalculator();

  @override
  String get name => 'Issue complexity ratio';

  @override
  double weightFrom(ScoringWeights weights) => weights.issueComplexity;

  @override
  FactorResult calculate(ProjectMetrics metrics) {
    if (metrics.closedIssueWeight <= 0) {
      // Nothing closed in this window. That is itself a signal, but velocity
      // is the factor that should report it, not this one.
      return const FactorResult(
        value: 50,
        detail: 'No issues closed in this window to compare against',
      );
    }

    // How heavy the average remaining item is, relative to the average item
    // the squad has been completing.
    final ratio = metrics.openIssueWeight / metrics.closedIssueWeight;

    // A ratio near 1 means remaining work resembles completed work, which is
    // healthy. Climbing above that means the backlog is getting top-heavy.
    final value = ratio <= 1
        ? clampScore(85 - (1 - ratio) * 15)
        : clampScore(85 - (ratio - 1) * 45);

    final detail = switch (ratio) {
      > 1.6 =>
        'Remaining issues are much heavier than what is being cleared — the hard work is stacking up',
      > 1.2 => 'Open issues skewing heavier as simpler work is cleared',
      < 0.8 => 'Remaining work is lighter than what has been cleared',
      _ => 'Backlog weight stable against completed work',
    };

    return FactorResult(value: value, detail: detail);
  }
}
