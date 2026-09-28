import '../../models/project.dart';
import '../../models/health_state.dart';
import '../../models/project_metrics.dart';
import '../../models/scoring_weights.dart';
import 'factor_calculator.dart';
import 'factor_calculators/budget_burn_calculator.dart';
import 'factor_calculators/commit_volume_calculator.dart';
import 'factor_calculators/complexity_ratio_calculator.dart';
import 'factor_calculators/idle_time_calculator.dart';
import 'factor_calculators/velocity_calculator.dart';

/// The result of scoring one project: a number and the reasoning behind it.
class HealthAssessment {
  const HealthAssessment({
    required this.projectId,
    required this.score,
    required this.factors,
  });

  final String projectId;

  /// 0–100 composite.
  final double score;

  /// Every contributing factor, with its value, weight and explanation.
  /// Always returned alongside the score, never separately — the breakdown is
  /// what makes a warning actionable.
  final List<HealthFactor> factors;

  HealthState get state => HealthState.fromScore(score);
}

/// Composes weighted indicators into a single health score.
///
/// Deliberately multi-dimensional. A single linear indicator is trivially
/// gamed — the research calls this out directly when discussing the Hawthorne
/// effect, where developers who know they are measured start optimising for
/// the measure instead of the work. Five indicators pulling in different
/// directions, each weighted, is far harder to fake than any one of them.
///
/// The engine knows nothing about what the indicators are. Adding one means
/// adding a calculator to the list; the arithmetic here does not change.
class HealthScoreEngine {
  const HealthScoreEngine({required this.calculators});

  /// The default set, matching the indicators named in the research proposal.
  HealthScoreEngine.standard()
    : calculators = const [
        BudgetBurnCalculator(),
        VelocityCalculator(),
        ComplexityRatioCalculator(),
        CommitVolumeCalculator(),
        IdleTimeCalculator(),
      ];

  final List<FactorCalculator> calculators;

  /// Scores one project.
  ///
  /// Weights are normalised before use rather than trusted. They are editable
  /// in settings, and weights that do not sum to 1 would silently produce a
  /// score outside the 0–100 scale the rest of the app assumes.
  HealthAssessment score({
    required ProjectMetrics metrics,
    ScoringWeights weights = const ScoringWeights.defaults(),
  }) {
    final results = <HealthFactor>[];
    var weightTotal = 0.0;

    for (final calculator in calculators) {
      final weight = calculator.weightFrom(weights);
      if (weight <= 0) continue; // an indicator turned off in settings
      weightTotal += weight;
    }

    if (weightTotal <= 0) {
      // Every indicator disabled. Report the neutral middle rather than
      // dividing by zero.
      return HealthAssessment(
        projectId: metrics.projectId,
        score: 50,
        factors: const [],
      );
    }

    var weighted = 0.0;

    for (final calculator in calculators) {
      final rawWeight = calculator.weightFrom(weights);
      if (rawWeight <= 0) continue;

      final normalisedWeight = rawWeight / weightTotal;
      final result = calculator.calculate(metrics);

      weighted += result.value * normalisedWeight;

      results.add(
        HealthFactor(
          name: calculator.name,
          value: result.value,
          weight: normalisedWeight,
          detail: result.detail,
        ),
      );
    }

    return HealthAssessment(
      projectId: metrics.projectId,
      score: clampScore(weighted),
      factors: results,
    );
  }
}
