import 'package:flutter_test/flutter_test.dart';

import 'package:keel/data/mock_project_repository.dart';
import 'package:keel/models/health_state.dart';
import 'package:keel/state/dashboard_notifier.dart';

/// Covers the ordering and filtering the dashboard depends on.
///
/// Worst-first is not cosmetic: in an early warning system, the project
/// needing attention has to be the one you see without scrolling.
void main() {
  late MockProjectRepository repo;

  setUp(() => repo = MockProjectRepository());
  tearDown(() => repo.dispose());

  test('worst-first puts the most severe project at the top', () async {
    final snapshot = await repo.watch().first;
    const view = DashboardView();

    final ordered = view.apply(snapshot.projects);

    for (var i = 1; i < ordered.length; i++) {
      expect(
        ordered[i - 1].state.severity,
        greaterThanOrEqualTo(ordered[i].state.severity),
        reason: 'projects must be ordered worst-first',
      );
    }
  });

  test('ties on severity are broken by the lower score', () async {
    final snapshot = await repo.watch().first;
    const view = DashboardView();

    final ordered = view.apply(snapshot.projects);

    for (var i = 1; i < ordered.length; i++) {
      if (ordered[i - 1].state == ordered[i].state) {
        expect(ordered[i - 1].score, lessThanOrEqualTo(ordered[i].score));
      }
    }
  });

  test('sorting by name does not drop any project', () async {
    final snapshot = await repo.watch().first;
    const view = DashboardView(sort: ProjectSort.nameAscending);

    final ordered = view.apply(snapshot.projects);

    expect(ordered.length, snapshot.projects.length);
    for (var i = 1; i < ordered.length; i++) {
      expect(
        ordered[i - 1].name.compareTo(ordered[i].name),
        lessThanOrEqualTo(0),
      );
    }
  });

  test('filtering by state shows only that state', () async {
    final snapshot = await repo.watch().first;
    const view = DashboardView(statesShown: {HealthState.critical});

    final filtered = view.apply(snapshot.projects);

    for (final project in filtered) {
      expect(project.state, HealthState.critical);
    }
  });

  test('searching matches project name or client', () async {
    final snapshot = await repo.watch().first;
    final target = snapshot.projects.first;

    final byName = const DashboardView().copyWith(query: target.name);
    expect(byName.apply(snapshot.projects), contains(target));

    final byClient = const DashboardView().copyWith(query: target.client);
    expect(byClient.apply(snapshot.projects), contains(target));
  });

  test('an unmatched search returns nothing rather than everything', () async {
    final snapshot = await repo.watch().first;
    final view = const DashboardView().copyWith(query: 'zzzzz-no-such-project');

    expect(view.apply(snapshot.projects), isEmpty);
  });

  test('state counts add up to the number of projects', () async {
    final snapshot = await repo.watch().first;

    final total = HealthState.values
        .map(snapshot.countIn)
        .fold<int>(0, (sum, count) => sum + count);

    expect(total, snapshot.projects.length);
  });
}
