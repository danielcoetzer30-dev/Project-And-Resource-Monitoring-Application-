import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel/app_shell.dart';
import 'package:keel/data/mock_comment_repository.dart';
import 'package:keel/data/mock_project_repository.dart';
import 'package:keel/data/mock_settings_repository.dart';
import 'package:keel/routing/app_router.dart';
import 'package:keel/routing/routes.dart';
import 'package:keel/screens/signal_thread_screen.dart';
import 'package:keel/state/providers.dart';
import 'package:keel/theme/app_theme.dart';
import 'package:keel/widgets/signal_card.dart';

import '../support/fake_auth_repository.dart';

/// Walks the app the way someone actually uses it: open it, read the
/// dashboard, move between tabs, open a project.
///
/// Runs against the mock repository, so it needs no Firebase, no network and
/// no credentials — which is the same reason the prototype can be demonstrated
/// on a phone with no signal.
void main() {
  /// The app with Firebase swapped out: a signed-in fake auth repository and
  /// the seeded mock instead of Firestore. Exactly the two overrides the
  /// interfaces exist to make possible.
  Widget app({bool themed = false}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        projectRepositoryProvider.overrideWith((ref) {
          final repository = MockProjectRepository();
          ref.onDispose(repository.dispose);
          return repository;
        }),
        commentRepositoryProvider.overrideWith((ref) {
          final repository = MockCommentRepository(
            author: FakeAuthRepository.demoUser,
          );
          ref.onDispose(repository.dispose);
          return repository;
        }),
        settingsRepositoryProvider.overrideWith((ref) {
          final repository = MockSettingsRepository(
            author: FakeAuthRepository.demoUser,
          );
          ref.onDispose(repository.dispose);
          return repository;
        }),
      ],
      child: MaterialApp(
        title: 'Keel',
        theme: themed ? AppTheme.dark : null,
        initialRoute: Routes.shell,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }

  Widget themedApp() => app(themed: true);

  /// Moves from Home to one of the data tabs.
  ///
  /// The nav bar and the Home cards both carry the section name, so tapping
  /// the last match reliably hits the bar.
  Future<void> openSection(WidgetTester tester, String name) async {
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets('opens on Home, not on a data view', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(); // let the first snapshot arrive

    expect(find.byType(AppShell), findsOneWidget);

    // Home is deliberately neutral: a health reading should not land on
    // someone the moment they open the app.
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Ledger rebuild'), findsNothing);
  });

  testWidgets('shows projects once Health is opened', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await openSection(tester, 'Health');

    expect(find.text('Ledger rebuild'), findsWidgets);
  });

  testWidgets('moves between every tab without error', (tester) async {
    await tester.pumpWidget(themedApp());
    await tester.pump();

    for (final label in [
      'Health',
      'Squads',
      'Signals',
      'Week',
      'Ask',
      'Home',
    ]) {
      await openSection(tester, label);
      expect(tester.takeException(), isNull, reason: '$label tab threw');
    }
  });

  testWidgets('opens a project and shows its factor breakdown', (tester) async {
    await tester.pumpWidget(themedApp());
    await tester.pump();

    await openSection(tester, 'Health');
    await tester.tap(find.text('Ledger rebuild').first);
    await tester.pumpAndSettle();

    // The breakdown is the point of the detail screen — a score with no
    // reasoning is not actionable. It sits below the score and the Seam, so
    // in a test viewport it is not built until scrolled to.
    await tester.scrollUntilVisible(
      find.text('WHAT IS DRIVING THE SCORE'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('WHAT IS DRIVING THE SCORE'), findsOneWidget);
    expect(find.text('Budget burn'), findsWidgets);
  });

  testWidgets('opens the discussion on a signal and adds to it', (
    tester,
  ) async {
    await tester.pumpWidget(themedApp());
    await tester.pump();

    await openSection(tester, 'Signals');
    await tester.tap(find.text('Discuss').first);
    await tester.pumpAndSettle();

    // The warning travels with its conversation: the card, with its reasoning,
    // sits above the thread rather than being left behind on the list.
    expect(find.text('DISCUSSION'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SignalThreadScreen),
        matching: find.byType(SignalCard),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Nobody has said anything yet'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Escalated to the client.');
    await tester.pump();
    await tester.tap(find.byTooltip('Post comment'));
    await tester.pumpAndSettle();

    expect(find.text('Escalated to the client.'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
