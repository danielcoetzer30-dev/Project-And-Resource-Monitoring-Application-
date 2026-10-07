import 'health_state.dart';
import '../widgets/health_seam.dart';

/// One contributing input to a health score.
///
/// The score is deliberately a matrix rather than a single number: a linear
/// indicator is trivially gamed, and showing the breakdown is what lets a team
/// act on a warning instead of just receiving it.
class HealthFactor {
  const HealthFactor({
    required this.name,
    required this.value,
    required this.weight,
    required this.detail,
  });

  final String name;

  /// 0–100, where higher is healthier.
  final double value;

  /// Contribution to the overall score. Weights across a project sum to 1.
  final double weight;

  /// Plain-language reading of what the number means right now.
  final String detail;

  HealthState get state => HealthState.fromScore(value);
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.client,
    required this.squadId,
    required this.score,
    required this.factors,
    required this.seam,
    required this.openSignals,
    required this.budgetBurn,
    required this.scheduleDaysRemaining,
    required this.loadSheddingHoursLost,
  });

  final String id;
  final String name;
  final String client;
  final String squadId;

  /// 0–100 composite.
  final double score;
  final List<HealthFactor> factors;
  final List<SeamSegment> seam;
  final int openSignals;

  /// Fraction of budget consumed, 0–1. Can exceed 1.
  final double budgetBurn;
  final int scheduleDaysRemaining;

  /// Hours lost to grid outages in the current window. Kept separate from the
  /// other inputs so a team is never scored down for a national power failure.
  final double loadSheddingHoursLost;

  HealthState get state => HealthState.fromScore(score);
}
