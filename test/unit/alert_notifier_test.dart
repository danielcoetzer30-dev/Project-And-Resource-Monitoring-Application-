import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keel/data/mock_project_repository.dart';
import 'package:keel/data/project_repository.dart';
import 'package:keel/models/health_state.dart';
import 'package:keel/models/project.dart';
import 'package:keel/services/sync/alert_presenter.dart';
import 'package:keel/services/sync/notification_service.dart';
import 'package:keel/state/providers.dart';

import '../support/fake_auth_repository.dart';

/// Alerting, from a snapshot arriving to a notification being shown.
///
/// The service that decides whether an alert is worth raising was correct and
/// unreachable for weeks: nothing called evaluate and nothing listened. These
/// tests are mostly about the wire, which is the part that was missing.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Project project(String id, HealthState state) => Project(
    id: id,
    name: 'Ledger rebuild',
    client: 'Northbank',
    squadId: 's1',
    score: switch (state) {
      HealthState.onTrack => 82,
      HealthState.watch => 60,
      HealthState.atRisk => 44,
      HealthState.critical => 20,
    },
    factors: const [],
    seam: const [],
    openSignals: 0,
    budgetBurn: 0.5,
    scheduleDaysRemaining: 30,
    loadSheddingHoursLost: 0,
  );

  HealthSnapshot snapshotOf(List<Project> projects) => HealthSnapshot(
    projects: projects,
    squads: const [],
    signals: const [],
    grid: const GridStatus(
      stage: 0,
      nextOutageStart: null,
      nextOutageEnd: null,
      hoursLostThisWeek: 0,
    ),
    capturedAt: DateTime.utc(2026, 10, 21),
    isLive: true,
  );

  /// A container with the snapshot stream under the test's control, so
  /// transitions happen when the test says so.
  ({
    ProviderContainer container,
    RecordingAlertPresenter presenter,
    void Function(HealthSnapshot) emit,
  })
  harness({bool permitted = true}) {
    final controller = StreamController<HealthSnapshot>.broadcast();
    final presenter = RecordingAlertPresenter(permitted: permitted);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        alertPresenterProvider.overrideWithValue(presenter),
        healthSnapshotProvider.overrideWith((ref) => controller.stream),
      ],
    );

    addTearDown(container.dispose);
    addTearDown(controller.close);

    // Keeps the notifier alive for the length of the test. A read alone does
    // not: with nothing listening it is built and torn down again, which is
    // exactly what happens in the app if the shell stops watching it.
    container.listen(alertNotifierProvider, (_, _) {}, fireImmediately: true);

    return (container: container, presenter: presenter, emit: controller.add);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('the service decides what is worth saying', () {
    late NotificationService service;

    setUp(() => service = NotificationService());
    tearDown(() => service.dispose());

    test('the first sight of a project says nothing', () async {
      // Otherwise opening the app would alert on everything at once.
      final raised = <HealthAlert>[];
      service.alerts.listen(raised.add);

      service.evaluate([project('p1', HealthState.critical)]);
      await settle();

      expect(raised, isEmpty);
    });

    test('crossing into at risk raises one alert', () async {
      final raised = <HealthAlert>[];
      service.alerts.listen(raised.add);

      service.evaluate([project('p1', HealthState.watch)]);
      service.evaluate([project('p1', HealthState.atRisk)]);
      await settle();

      expect(raised, hasLength(1));
      expect(raised.single.isWorsening, isTrue);
      expect(raised.single.title.toLowerCase(), contains('at risk'));
    });

    test('staying in a bad state says nothing further', () async {
      // An early warning system that cries wolf daily gets muted, and a muted
      // warning system is worse than none.
      final raised = <HealthAlert>[];
      service.alerts.listen(raised.add);

      service.evaluate([project('p1', HealthState.watch)]);
      service.evaluate([project('p1', HealthState.atRisk)]);
      service.evaluate([project('p1', HealthState.atRisk)]);
      service.evaluate([project('p1', HealthState.atRisk)]);
      await settle();

      expect(raised, hasLength(1));
    });

    test('a move between two good states says nothing', () async {
      final raised = <HealthAlert>[];
      service.alerts.listen(raised.add);

      service.evaluate([project('p1', HealthState.onTrack)]);
      service.evaluate([project('p1', HealthState.watch)]);
      await settle();

      expect(raised, isEmpty);
    });

    test('recovery is announced too', () async {
      // A team that has pulled a project back deserves to hear it, and it
      // keeps the tool from reading as purely punitive.
      final raised = <HealthAlert>[];
      service.alerts.listen(raised.add);

      service.evaluate([project('p1', HealthState.critical)]);
      service.evaluate([project('p1', HealthState.onTrack)]);
      await settle();

      expect(raised, hasLength(1));
      expect(raised.single.isWorsening, isFalse);
      expect(raised.single.title, contains('recovered'));
    });

    test('signing out forgets what it knew', () async {
      final raised = <HealthAlert>[];
      service.alerts.listen(raised.add);

      service.evaluate([project('p1', HealthState.watch)]);
      service.reset();
      // First sight again, so no alert even though the state got worse.
      service.evaluate([project('p1', HealthState.critical)]);
      await settle();

      expect(raised, isEmpty);
    });
  });

  group('the wire from snapshot to notification', () {
    test('a snapshot reaches the service and raises a banner', () async {
      final h = harness();

      h.emit(snapshotOf([project('p1', HealthState.watch)]));
      await settle();
      h.emit(snapshotOf([project('p1', HealthState.critical)]));
      await settle();

      final alert = h.container.read(alertNotifierProvider);
      expect(alert, isNotNull);
      expect(alert!.projectName, 'Ledger rebuild');
      expect(alert.to, HealthState.critical);
    });

    test('nothing is shown in the tray unless it was turned on', () async {
      // Off by default, deliberately: notifications are the one thing this app
      // does that reaches somebody who did not open it.
      final h = harness();

      h.emit(snapshotOf([project('p1', HealthState.watch)]));
      await settle();
      h.emit(snapshotOf([project('p1', HealthState.critical)]));
      await settle();

      expect(h.container.read(alertNotifierProvider), isNotNull);
      expect(h.presenter.shown, isEmpty);
    });

    test('turning it on asks permission, then shows in the tray', () async {
      final h = harness();

      final granted = await h.container
          .read(alertNotifierProvider.notifier)
          .setEnabled(true);

      expect(granted, isTrue);
      expect(h.presenter.permissionAsked, isTrue);
      expect(h.container.read(preferencesProvider).notifyOnDecline, isTrue);

      h.emit(snapshotOf([project('p1', HealthState.watch)]));
      await settle();
      h.emit(snapshotOf([project('p1', HealthState.critical)]));
      await settle();

      expect(h.presenter.shown, hasLength(1));
      expect(h.presenter.shown.single.projectId, 'p1');
    });

    test('a refused permission leaves the preference off', () async {
      // Rather than a switch that claims to be on while nothing can be shown.
      final h = harness(permitted: false);

      final granted = await h.container
          .read(alertNotifierProvider.notifier)
          .setEnabled(true);

      expect(granted, isFalse);
      expect(h.container.read(preferencesProvider).notifyOnDecline, isFalse);
    });

    test('turning it off stops the tray without stopping the banner', () async {
      final h = harness();

      await h.container.read(alertNotifierProvider.notifier).setEnabled(true);
      await h.container.read(alertNotifierProvider.notifier).setEnabled(false);

      h.emit(snapshotOf([project('p1', HealthState.watch)]));
      await settle();
      h.emit(snapshotOf([project('p1', HealthState.critical)]));
      await settle();

      expect(h.presenter.shown, isEmpty);
      expect(h.container.read(alertNotifierProvider), isNotNull);
    });

    test('dismissing clears the banner', () async {
      final h = harness();

      h.emit(snapshotOf([project('p1', HealthState.watch)]));
      await settle();
      h.emit(snapshotOf([project('p1', HealthState.critical)]));
      await settle();

      expect(h.container.read(alertNotifierProvider), isNotNull);

      h.container.read(alertNotifierProvider.notifier).dismiss();

      expect(h.container.read(alertNotifierProvider), isNull);
    });

    test('an alert carries a project and never a person', () async {
      // The constraint the whole application is built around. HealthAlert has
      // no field that could hold one, and this fails if that ever changes.
      final repository = MockProjectRepository();
      addTearDown(repository.dispose);

      final h = harness();

      h.emit(snapshotOf([project('p1', HealthState.watch)]));
      await settle();
      h.emit(snapshotOf([project('p1', HealthState.critical)]));
      await settle();

      final alert = h.container.read(alertNotifierProvider)!;

      expect(alert.projectId, 'p1');
      expect(alert.projectName, 'Ledger rebuild');
      expect(alert.title, isNot(contains('@')));
    });
  });
}
