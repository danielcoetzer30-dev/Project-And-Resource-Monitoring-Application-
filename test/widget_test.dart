import 'package:flutter_test/flutter_test.dart';

import 'package:keel/data/mock_project_repository.dart';
import 'package:keel/models/health_state.dart';

void main() {
  test('scores map onto the expected states', () {
    expect(HealthState.fromScore(90), HealthState.onTrack);
    expect(HealthState.fromScore(60), HealthState.watch);
    expect(HealthState.fromScore(40), HealthState.atRisk);
    expect(HealthState.fromScore(20), HealthState.critical);
  });

  test('mock repository emits a snapshot with seeded data', () async {
    final repo = MockProjectRepository();
    final snapshot = await repo.watch().first;

    expect(snapshot.projects, isNotEmpty);
    expect(snapshot.squads, isNotEmpty);
    expect(snapshot.signals, isNotEmpty);
    // Worst-first ordering is what the dashboard depends on.
    expect(
      snapshot.worstFirst.first.state.severity,
      greaterThanOrEqualTo(snapshot.worstFirst.last.state.severity),
    );

    repo.dispose();
  });

  test('every project carries its health factor breakdown', () async {
    final repo = MockProjectRepository();
    final snapshot = await repo.watch().first;

    // A single opaque number is gameable and unactionable; the breakdown is
    // the point.
    for (final project in snapshot.projects) {
      expect(project.factors.length, greaterThan(1));
      final totalWeight =
          project.factors.fold<double>(0, (sum, f) => sum + f.weight);
      expect(totalWeight, closeTo(1.0, 0.001));
    }

    repo.dispose();
  });
}
