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
    this.scheduleTotalDays = 0,
    this.velocityRatio = 1,
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

  /// Total planned duration in days. Needed to work out a burn *rate* rather
  /// than a burn *total*: 94% spent means nothing until you know whether that
  /// took three weeks or three months.
  ///
  /// Zero means unknown, and every forecast derived from it is suppressed
  /// rather than guessed.
  final int scheduleTotalDays;

  /// Throughput against this squad's own recent baseline. 1.0 is on baseline,
  /// 0.62 means running at 62% of it.
  ///
  /// Held here as well as in the factor breakdown because a forecast needs the
  /// raw ratio, not the 0–100 score the ratio was turned into.
  final double velocityRatio;

  HealthState get state => HealthState.fromScore(score);

  /// Days of the plan already spent. Null when the total is unknown.
  int? get scheduleElapsedDays {
    if (scheduleTotalDays <= 0) return null;
    final elapsed = scheduleTotalDays - scheduleDaysRemaining;
    return elapsed > 0 ? elapsed : null;
  }
}
