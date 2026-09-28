import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scoring_weights.dart';

/// Scoring weights as the settings screen holds them.
///
/// Kept separate from the saved value so a team can drag sliders around and
/// see the total before committing, and so an invalid combination can be shown
/// as invalid rather than silently rejected on save.
class WeightsDraft {
  const WeightsDraft({required this.weights, this.isDirty = false});

  final ScoringWeights weights;
  final bool isDirty;

  bool get canSave => isDirty && weights.isValid;

  /// How far off 1.0 the weights currently sum, for the hint under the sliders.
  double get drift => weights.total - 1.0;
}

/// Owns the scoring weights a team is editing.
///
/// Exposing these at all is a deliberate design position: the score is not a
/// black box. A team that can see and change what it is measured on is far
/// more likely to trust the result — and the research raises exactly that
/// concern, where opaque metrics get read as surveillance.
class SettingsNotifier extends Notifier<WeightsDraft> {
  @override
  WeightsDraft build() =>
      const WeightsDraft(weights: ScoringWeights.defaults());

  void setBudgetBurn(double value) =>
      _update(state.weights.copyWith(budgetBurn: value));

  void setTaskVelocity(double value) =>
      _update(state.weights.copyWith(taskVelocity: value));

  void setIssueComplexity(double value) =>
      _update(state.weights.copyWith(issueComplexity: value));

  void setCommitVolume(double value) =>
      _update(state.weights.copyWith(commitVolume: value));

  void setIdleTime(double value) =>
      _update(state.weights.copyWith(idleTime: value));

  void resetToDefaults() => state = const WeightsDraft(
    weights: ScoringWeights.defaults(),
    isDirty: true,
  );

  /// Scales every weight so they sum to exactly 1, preserving their relative
  /// sizes. Easier than asking someone to do the arithmetic themselves.
  void normalise() {
    final total = state.weights.total;
    if (total <= 0) return;

    _update(
      ScoringWeights(
        budgetBurn: state.weights.budgetBurn / total,
        taskVelocity: state.weights.taskVelocity / total,
        issueComplexity: state.weights.issueComplexity / total,
        commitVolume: state.weights.commitVolume / total,
        idleTime: state.weights.idleTime / total,
      ),
    );
  }

  /// Called after a successful save, so the screen stops offering to save.
  void markSaved() => state = WeightsDraft(weights: state.weights);

  void _update(ScoringWeights weights) =>
      state = WeightsDraft(weights: weights, isDirty: true);
}
