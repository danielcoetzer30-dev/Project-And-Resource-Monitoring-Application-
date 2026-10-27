import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prahm/data/project_repository.dart';
import 'package:prahm/models/health_state.dart';
import 'package:prahm/models/project.dart';
import 'package:prahm/models/signal.dart';
import 'package:prahm/screens/signals_screen.dart';

/// A snapshot carrying [signals] and [projects] and nothing else of interest.
HealthSnapshot _snapshot({
  required List<Signal> signals,
  List<Project> projects = const [],
}) {
  return HealthSnapshot(
    projects: projects,
    squads: const [],
    signals: signals,
    grid: const GridStatus(
      stage: 0,
      nextOutageStart: null,
      nextOutageEnd: null,
      hoursLostThisWeek: 0,
    ),
    capturedAt: DateTime(2026, 10, 27),
    isLive: true,
  );
}

Signal _signal({String projectId = 'p9'}) {
  return Signal(
    id: 'sig1',
    title: 'Budget burn is ahead of schedule',
    because: 'Seventy per cent spent at the halfway mark.',
    severity: HealthState.watch,
    projectId: projectId,
    raisedAt: DateTime(2026, 10, 26),
  );
}

Widget _host(HealthSnapshot snapshot) {
  return MaterialApp(home: Scaffold(body: SignalsScreen(snapshot: snapshot)));
}

void main() {
  group('a signal whose project is not in the snapshot', () {
    // The repository emits as each collection arrives, so signals can land a
    // frame before projects. The screen has to survive that.
    testWidgets('renders when the project list is empty', (tester) async {
      await tester.pumpWidget(_host(_snapshot(signals: [_signal()])));

      expect(tester.takeException(), isNull);
      expect(find.text('Budget burn is ahead of schedule'), findsOneWidget);
    });

    // Worse than showing nothing: naming the wrong project attributes a
    // warning to a team it is not about.
    testWidgets('does not borrow another project\'s name', (tester) async {
      await tester.pumpWidget(
        _host(
          _snapshot(
            signals: [_signal(projectId: 'missing')],
            projects: [
              const Project(
                id: 'p1',
                name: 'Sit and Stay',
                client: 'Acme',
                squadId: 's1',
                score: 90,
                factors: [],
                seam: [],
                openSignals: 0,
                budgetBurn: 0.4,
                scheduleDaysRemaining: 30,
                loadSheddingHoursLost: 0,
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Sit and Stay'), findsNothing);
    });
  });
}
