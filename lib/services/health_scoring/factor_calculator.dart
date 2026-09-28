import '../../models/project_metrics.dart';
import '../../models/scoring_weights.dart';

/// What a calculator produces: a number and the sentence explaining it.
///
/// The sentence is not optional. A score a team cannot interpret is a score
/// they cannot act on, and an unexplained number is what makes monitoring feel
/// like surveillance rather than support.
class FactorResult {
  const FactorResult({required this.value, required this.detail});

  /// 0–100, where higher is healthier.
  final double value;

  /// Plain-language reading of what the number means right now.
  final String detail;
}

/// One indicator of project health.
///
/// Each indicator is its own class implementing this, so adding an indicator
/// means adding a file rather than editing the engine. That matters here
/// because which indicators predict failure is the open research question —
/// the set is expected to change once interview data comes back.
abstract interface class FactorCalculator {
  /// Shown as the factor name on the project detail screen.
  String get name;

  /// How much this indicator counts, pulled from the organisation's settings.
  double weightFrom(ScoringWeights weights);

  FactorResult calculate(ProjectMetrics metrics);
}

/// Clamps a value into the 0–100 range the whole app assumes.
///
/// Shared by every calculator so none of them can quietly produce a number
/// outside the scale and skew the composite.
double clampScore(double value) {
  if (value < 0) return 0;
  if (value > 100) return 100;
  return value;
}

/// Converts a ratio of actual-to-expected into a 0–100 score.
///
/// A ratio of 1 (meeting the baseline) scores 75, which is the bottom of "On
/// track". Doing better pushes toward 100; falling behind drops away steeply,
/// because the tool exists to notice decline early rather than to reward
/// overperformance.
double scoreFromRatio(double ratio) {
  if (ratio <= 0) return 0;
  if (ratio >= 1) {
    // Above baseline, improvements taper: 1.0 -> 75, 1.5 -> ~87, 2.0 -> 100.
    return clampScore(75 + (ratio - 1) * 50);
  }
  // Below baseline, decline is close to linear so a drop is visible quickly.
  return clampScore(ratio * 75);
}
