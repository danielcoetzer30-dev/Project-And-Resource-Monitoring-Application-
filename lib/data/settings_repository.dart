import '../models/scoring_weights.dart';

/// Per-organisation settings, as an interface.
///
/// Only scoring weights for now. Kept separate from the project repository
/// because settings are written by people and read rarely, while project data
/// is written by ingestion and read constantly.
abstract interface class SettingsRepository {
  /// Emits the organisation's weights, falling back to the defaults when none
  /// have been saved.
  Stream<ScoringWeights> watchWeights(String orgId);

  /// Rejects weights that do not sum to 1, since the resulting score would not
  /// be on a 0-100 scale.
  Future<void> saveWeights({
    required String orgId,
    required ScoringWeights weights,
  });
}
