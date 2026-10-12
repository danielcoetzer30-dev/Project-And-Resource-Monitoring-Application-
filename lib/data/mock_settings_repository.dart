import 'dart:async';

import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/scoring_weights.dart';
import 'settings_repository.dart';

/// An in-memory [SettingsRepository], for tests and for running the app with
/// no backend.
///
/// Applies the same two refusals as the real one — role, then validity — so a
/// test that passes here cannot be relying on something Firestore would
/// reject.
class MockSettingsRepository implements SettingsRepository {
  MockSettingsRepository({this.author, ScoringWeights? initial})
    : _saved = initial ?? const ScoringWeights.defaults();

  /// Who [saveWeights] writes as. Null stands for signed out, which cannot
  /// save, matching the real repository.
  final AppUser? author;

  ScoringWeights _saved;
  final _changed = StreamController<ScoringWeights>.broadcast();

  /// What a save actually left behind, for a test to assert on.
  ScoringWeights get saved => _saved;

  @override
  Stream<ScoringWeights> watchWeights(String orgId) {
    // Stream.multi rather than async*: every listener gets the current value
    // at once and each later change after it, which is how Firestore's
    // snapshots() behaves. An async* generator only subscribes to the change
    // stream once it is resumed, and some listeners never resume it.
    return Stream<ScoringWeights>.multi((controller) {
      controller.add(_saved);
      final subscription = _changed.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> saveWeights({
    required String orgId,
    required ScoringWeights weights,
  }) async {
    if (author == null || !author!.canChangeSettings) {
      throw const PermissionException(
        'Only leads and managers can change scoring weights.',
      );
    }

    if (!weights.isValid) {
      throw const ValidationException(
        'Scoring weights have to add up to 100% before they can be saved.',
      );
    }

    _saved = weights;
    _changed.add(weights);
  }

  void dispose() => _changed.close();
}
