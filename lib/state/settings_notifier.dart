import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failure.dart';
import '../models/scoring_weights.dart';
import 'auth_notifier.dart';
import 'providers.dart';

/// Scoring weights as the settings screen holds them.
///
/// Kept separate from the saved value so a team can drag sliders around and
/// see the total before committing, and so an invalid combination can be shown
/// as invalid rather than silently rejected on save.
class WeightsDraft {
  const WeightsDraft({
    required this.weights,
    this.isDirty = false,
    this.isSaving = false,
    this.failure,
  });

  final ScoringWeights weights;

  /// Edited since the last load or save, so there is something worth saving.
  final bool isDirty;

  /// A save is in flight. The button says so rather than appearing to do
  /// nothing, which on a slow connection is the difference between "saving"
  /// and "broken".
  final bool isSaving;

  /// Why the last save was refused, or null if it was not.
  final Failure? failure;

  bool get canSave => isDirty && weights.isValid && !isSaving;

  /// How far off 1.0 the weights currently sum, for the hint under the sliders.
  double get drift => weights.total - 1.0;
}

/// The weights as last saved for the signed-in user's organisation.
///
/// Falls back to the defaults when nobody is signed in, so the settings screen
/// renders and explains itself rather than sitting on a spinner.
final savedWeightsProvider = StreamProvider<ScoringWeights>((ref) {
  final user = ref.watch(currentUserProvider);
  return ref.watch(settingsRepositoryProvider).watchWeights(user?.orgId ?? '');
});

/// Owns the scoring weights a team is editing.
///
/// Exposing these at all is a deliberate design position: the score is not a
/// black box. A team that can see and change what it is measured on is far
/// more likely to trust the result, and the research raises exactly that
/// concern, where opaque metrics get read as surveillance.
class SettingsNotifier extends Notifier<WeightsDraft> {
  @override
  WeightsDraft build() {
    // Follow the saved value, but never over an edit in progress: somebody
    // dragging a slider while a teammate saves should not have it snatched
    // away mid-gesture. Their own save is what resolves the difference.
    ref.listen(savedWeightsProvider, (_, next) {
      final saved = next.value;
      if (saved == null || state.isDirty || state.isSaving) return;
      state = WeightsDraft(weights: saved);
    });

    // Null while the first value is still in flight, which is why this falls
    // back to the defaults rather than waiting.
    final initial = ref.read(savedWeightsProvider).value;
    return WeightsDraft(weights: initial ?? const ScoringWeights.defaults());
  }

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

  void resetToDefaults() => _update(const ScoringWeights.defaults());

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

  /// Writes the draft to the organisation's settings document.
  ///
  /// The repository checks the signed-in role and the weights themselves, and
  /// `firestore.rules` checks the role again. A refusal from any of those
  /// lands in [WeightsDraft.failure] with the draft still intact, so nobody
  /// loses their work to a failed write.
  Future<void> save() async {
    if (!state.canSave) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = WeightsDraft(
        weights: state.weights,
        isDirty: true,
        failure: const AuthFailure('Sign in to save scoring weights.'),
      );
      return;
    }

    state = WeightsDraft(weights: state.weights, isDirty: true, isSaving: true);

    try {
      await ref
          .read(settingsRepositoryProvider)
          .saveWeights(orgId: user.orgId, weights: state.weights);

      // Clean: isDirty false, so the save button stops offering itself and
      // the listener above resumes following the saved value.
      state = WeightsDraft(weights: state.weights);
    } catch (error) {
      state = WeightsDraft(
        weights: state.weights,
        isDirty: true,
        failure: failureFromException(error),
      );
    }
  }

  /// Any edit clears the last failure: the message was about the weights as
  /// they were, and they have just changed.
  void _update(ScoringWeights weights) =>
      state = WeightsDraft(weights: weights, isDirty: true);
}
