import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel/app_shell.dart';
import 'package:keel/routing/app_router.dart';
import 'package:keel/routing/routes.dart';
import 'package:keel/theme/app_theme.dart';

/// Walks the app the way someone actually uses it: open it, read the
/// dashboard, move between tabs, open a project.
///
/// Runs against the mock repository, so it needs no Firebase, no network and
/// no credentials — which is the same reason the prototype can be demonstrated
/// on a phone with no signal.
void main() {
  Widget app() {
    return const ProviderScope(
      child: MaterialApp(
        title: 'Keel',
        initialRoute: Routes.shell,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }

  Widget themedApp() {
    return ProviderScope(
      child: MaterialApp(
        title: 'Keel',
        theme: AppTheme.dark,
        initialRoute: Routes.shell,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }

  testWidgets('opens on the health dashboard', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(); // let the first snapshot arrive

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Health'), findsWidgets);
  });

  testWidgets('shows projects once the snapshot arrives', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('NEEDS ATTENTION FIRST'), findsOneWidget);
    expect(find.text('Ledger rebuild'), findsWidgets);
  });

  testWidgets('moves between all four tabs without error', (tester) async {
    await tester.pumpWidget(themedApp());
    await tester.pump();

    for (final label in ['Squads', 'Signals', 'Grid']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$label tab threw');
    }
  });

  testWidgets('opens a project and shows its factor breakdown', (tester) async {
    await tester.pumpWidget(themedApp());
    await tester.pump();

    await tester.tap(find.text('Ledger rebuild').first);
    await tester.pumpAndSettle();

    // The breakdown is the point of the detail screen — a score with no
    // reasoning is not actionable.
    expect(find.text('WHAT IS DRIVING THE SCORE'), findsOneWidget);
    expect(find.text('Budget burn'), findsWidgets);
  });

  testWidgets('reaches settings and the scoring weights screen', (
    tester,
  ) async {
    await tester.pumpWidget(themedApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.text('Scoring weights'));
    await tester.pumpAndSettle();

    // A team must be able to see and change what it is measured on.
    expect(find.text('Budget burn'), findsWidgets);

    // The totals row sits below five sliders, so in a test viewport it is not
    // built until scrolled to.
    await tester.scrollUntilVisible(
      find.text('Weights add up to 100%'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Weights add up to 100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
