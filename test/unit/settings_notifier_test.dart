import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prahm/core/errors/failure.dart';
import 'package:prahm/data/mock_settings_repository.dart';
import 'package:prahm/models/app_user.dart';
import 'package:prahm/models/scoring_weights.dart';
import 'package:prahm/state/providers.dart';
import 'package:prahm/state/settings_notifier.dart';

import '../support/fake_auth_repository.dart';

/// Weights are the one piece of scoring configuration a team owns, so a save
/// that silently does nothing is worse than no save button: the team believes
/// it has changed what it is measured on when it has not.
void main() {
  const developer = AppUser(
    id: 'dev-uid',
    email: 'dev@example.com',
    displayName: 'Dev',
    orgId: 'demo-org',
    role: UserRole.developer,
  );

  /// A container with auth and settings both faked, so nothing reaches
  /// Firebase.
  ({ProviderContainer container, MockSettingsRepository repository}) harness({
    AppUser? as = FakeAuthRepository.demoUser,
    ScoringWeights? alreadySaved,
  }) {
    final repository = MockSettingsRepository(
      author: as,
      initial: alreadySaved,
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(signedIn: as != null, user: as),
        ),
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
    );

    addTearDown(container.dispose);
    addTearDown(repository.dispose);
    return (container: container, repository: repository);
  }

  /// Keeps the notifier alive, as a mounted screen would, so the stream
  /// listener in build() is not disposed immediately.
  void listen(ProviderContainer container) {
    container.listen(settingsProvider, (_, _) {}, fireImmediately: true);
    container.listen(savedWeightsProvider, (_, _) {}, fireImmediately: true);
  }

  /// Waits until the saved-weights stream has actually delivered [expected].
  ///
  /// Without this the assertions below pass whether or not the notifier
  /// handles the new value, because nothing has arrived yet to handle.
  Future<void> untilSavedIs(
    ProviderContainer container,
    ScoringWeights expected,
  ) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      final saved = container.read(savedWeightsProvider).value;
      if (saved != null &&
          saved.toMap().toString() == expected.toMap().toString()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    fail('the saved weights stream never delivered the new value');
  }

  test(
    'a lead saves the draft, and the saved value is what was on screen',
    () async {
      final (container: container, repository: repository) = harness();
      listen(container);
      await container.read(savedWeightsProvider.future);

      final notifier = container.read(settingsProvider.notifier);
      // Move weight off commit volume and onto budget burn, keeping the total
      // at 1 so it is a legal save.
      notifier.setCommitVolume(0.05);
      notifier.setBudgetBurn(0.35);

      expect(container.read(settingsProvider).isDirty, isTrue);

      await notifier.save();

      expect(repository.saved.commitVolume, 0.05);
      expect(repository.saved.budgetBurn, 0.35);
      expect(container.read(settingsProvider).isDirty, isFalse);
      expect(container.read(settingsProvider).failure, isNull);
    },
  );

  test(
    'a developer is refused, and keeps the draft they were working on',
    () async {
      final (container: container, repository: repository) = harness(
        as: developer,
      );
      listen(container);
      await container.read(savedWeightsProvider.future);

      final notifier = container.read(settingsProvider.notifier);
      notifier.setCommitVolume(0.05);
      notifier.setBudgetBurn(0.35);
      await notifier.save();

      final draft = container.read(settingsProvider);
      expect(draft.failure, isA<PermissionFailure>());
      // The work survives the refusal. Losing it would punish someone for not
      // knowing a permission they cannot see.
      expect(draft.weights.commitVolume, 0.05);
      expect(draft.isDirty, isTrue);
      expect(
        repository.saved.commitVolume,
        const ScoringWeights.defaults().commitVolume,
      );
    },
  );

  test(
    'weights that do not add up to 100% are not offered as saveable',
    () async {
      final (container: container, repository: _) = harness();
      listen(container);
      await container.read(savedWeightsProvider.future);

      final notifier = container.read(settingsProvider.notifier);
      notifier.setBudgetBurn(0.9);

      final draft = container.read(settingsProvider);
      expect(draft.weights.isValid, isFalse);
      expect(draft.canSave, isFalse);
    },
  );

  test('opens on what was last saved, not on the defaults', () async {
    const stored = ScoringWeights(
      budgetBurn: 0.4,
      taskVelocity: 0.2,
      issueComplexity: 0.2,
      commitVolume: 0.1,
      idleTime: 0.1,
    );

    final (container: container, repository: _) = harness(alreadySaved: stored);
    listen(container);
    await container.read(savedWeightsProvider.future);

    expect(container.read(settingsProvider).weights.budgetBurn, 0.4);
    expect(container.read(settingsProvider).isDirty, isFalse);
  });

  test('an edit in progress is not overwritten by a teammate saving', () async {
    final (container: container, repository: repository) = harness();
    listen(container);
    await container.read(savedWeightsProvider.future);

    final notifier = container.read(settingsProvider.notifier);
    notifier.setBudgetBurn(0.35);

    // Somebody else saves while this person is mid-edit.
    const theirs = ScoringWeights(
      budgetBurn: 0.1,
      taskVelocity: 0.1,
      issueComplexity: 0.1,
      commitVolume: 0.1,
      idleTime: 0.6,
    );
    await repository.saveWeights(orgId: 'demo-org', weights: theirs);
    await untilSavedIs(container, theirs);

    // Their slider is still where they left it.
    expect(container.read(settingsProvider).weights.budgetBurn, 0.35);
  });
}
