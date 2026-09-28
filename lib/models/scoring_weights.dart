/// How much each indicator contributes to a project's health score.
///
/// Configurable per organisation because the research does not assume the same
/// indicators matter equally to every team. Exposing these in settings is also
/// what keeps the score from being a black box — a team can see, and change,
/// what it is being measured on.
class ScoringWeights {
  const ScoringWeights({
    required this.budgetBurn,
    required this.taskVelocity,
    required this.issueComplexity,
    required this.commitVolume,
    required this.idleTime,
  });

  const ScoringWeights.defaults()
    : budgetBurn = 0.25,
      taskVelocity = 0.25,
      issueComplexity = 0.20,
      commitVolume = 0.15,
      idleTime = 0.15;

  final double budgetBurn;
  final double taskVelocity;
  final double issueComplexity;
  final double commitVolume;
  final double idleTime;

  double get total =>
      budgetBurn + taskVelocity + issueComplexity + commitVolume + idleTime;

  /// Weights have to sum to 1 or the resulting score is not on a 0-100 scale.
  /// Checked rather than assumed, because settings are user-editable.

  bool get isValid => (total - 1.0).abs() < 0.001;

  ScoringWeights copyWith({
    double? budgetBurn,
    double? taskVelocity,
    double? issueComplexity,
    double? commitVolume,
    double? idleTime,
  }) {
    return ScoringWeights(
      budgetBurn: budgetBurn ?? this.budgetBurn,
      taskVelocity: taskVelocity ?? this.taskVelocity,
      issueComplexity: issueComplexity ?? this.issueComplexity,
      commitVolume: commitVolume ?? this.commitVolume,
      idleTime: idleTime ?? this.idleTime,
    );
  }
}
