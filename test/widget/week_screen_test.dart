import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prahm/data/mock_project_repository.dart';
import 'package:prahm/data/project_repository.dart';
import 'package:prahm/screens/week_screen.dart';
import 'package:prahm/theme/app_theme.dart';

/// The Week tab carries the promise in constraint 2: outage hours are
/// reported, never deducted. The arithmetic is tested in
/// health_score_engine_test.dart; what is tested here is that a team reading
/// the screen is actually told so.
void main() {
  /// One snapshot from the seeded mock, with the repository shut down again
  /// before the widget is pumped — it drifts its numbers on a periodic timer,
  /// which a widget test will not tolerate outliving the tree.
  Future<HealthSnapshot> seeded() async {
    final repo = MockProjectRepository();
    final snapshot = await repo.watch().first;
    repo.dispose();
    return snapshot;
  }

  Future<void> pumpWeek(WidgetTester tester, HealthSnapshot snapshot) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: WeekScreen(snapshot: snapshot)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The screen is taller than a phone, so anything below the week strip has
  /// to be scrolled to before it can be asserted on.
  Future<void> scrollTo(WidgetTester tester, Finder target) {
    return tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('lays out the week and every project on it', (tester) async {
    final snapshot = await seeded();
    await pumpWeek(tester, snapshot);

    // Seven day columns, each labelled.
    expect(find.text('MON'), findsWidgets);

    for (final project in snapshot.projects) {
      expect(
        find.text(project.name),
        findsWidgets,
        reason: '${project.name} is missing from the week',
      );
    }
  });

  testWidgets('states the hours lost, and that they are never deducted', (
    tester,
  ) async {
    final snapshot = await seeded();
    await pumpWeek(tester, snapshot);

    final total = snapshot.projects
        .fold<double>(0, (sum, p) => sum + p.loadSheddingHoursLost)
        .toStringAsFixed(1);

    // Panel uppercases its title.
    await scrollTo(tester, find.text('HOURS LOST THIS WEEK'));
    expect(find.text(total), findsOneWidget);

    final promise = find.textContaining('excluded from every health score');
    await scrollTo(tester, promise);
    expect(promise, findsOneWidget);
  });

  testWidgets('names the load-shedding stage, not just that it is on', (
    tester,
  ) async {
    final snapshot = await seeded();
    await pumpWeek(tester, snapshot);

    // Stage 2 and stage 6 are different days, and the number is the first
    // thing a team here asks. "SHEDDING" alone does not answer it.
    expect(snapshot.grid.isShedding, isTrue, reason: 'the seed sheds');
    expect(find.text('STAGE ${snapshot.grid.stage} SHEDDING'), findsOneWidget);
  });

  testWidgets('does not present a future day as outage-free', (tester) async {
    final snapshot = await seeded();
    await pumpWeek(tester, snapshot);

    // The day circles are the only two-digit numbers in the strip, so the
    // fourth of them is the fourth day ahead.
    final dayCircles = find.byType(GestureDetector);
    await tester.tap(dayCircles.at(3));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('only known for today'),
      findsOneWidget,
      reason: 'an unknown outage schedule must not read as "no outages"',
    );
  });
}
