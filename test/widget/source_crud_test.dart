import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prahm/data/mock_source_repository.dart';
import 'package:prahm/data/project_repository.dart';
import 'package:prahm/models/app_user.dart';
import 'package:prahm/models/ingestion_source.dart';
import 'package:prahm/models/squad.dart';
import 'package:prahm/routing/app_router.dart';
import 'package:prahm/routing/routes.dart';
import 'package:prahm/state/providers.dart';
import 'package:prahm/theme/app_theme.dart';
import 'package:prahm/widgets/confirm_dialog.dart';

import '../support/fake_auth_repository.dart';

/// Connected sources, end to end: list, open, change, pause, remove.
///
/// This is the module where a record genuinely disappears. A project is
/// archived rather than deleted, because removing a failing project is the
/// easiest way to make it stop looking bad — a source is a statement about
/// where to read from, and removing one destroys no history, so here delete
/// means delete.
void main() {
  const lead = AppUser(
    id: 'lead-uid',
    email: 'lead@example.com',
    displayName: 'Lead',
    orgId: 'demo-org',
    role: UserRole.lead,
  );

  const developer = AppUser(
    id: 'dev-uid',
    email: 'dev@example.com',
    displayName: 'Dev',
    orgId: 'demo-org',
    role: UserRole.developer,
  );

  final source = IngestionSource(
    id: 'src1',
    type: SourceType.github,
    label: 'Riverpod (demonstration data)',
    remoteId: 'rrousselGit/riverpod',
    orgId: 'demo-org',
    isEnabled: true,
    squadId: 's1',
    lastSyncedAt: DateTime.utc(2026, 10, 21, 4),
  );

  const squads = [
    Squad(
      id: 's1',
      name: 'Platform squad',
      headcount: 2,
      capacityUsed: 0.61,
      activeProjectCount: 2,
      velocityTrend: -0.1,
    ),
    Squad(
      id: 's2',
      name: 'Mobile squad',
      headcount: 2,
      capacityUsed: 0.4,
      activeProjectCount: 1,
      velocityTrend: 0.05,
    ),
  ];

  final snapshot = HealthSnapshot(
    projects: const [],
    squads: squads,
    signals: const [],
    grid: const GridStatus(
      stage: 0,
      nextOutageStart: null,
      nextOutageEnd: null,
      hoursLostThisWeek: 0,
    ),
    capturedAt: DateTime.utc(2026, 10, 21, 9),
    isLive: true,
  );

  late MockSourceRepository repository;

  /// The real router, so the test exercises the route guard as well as the
  /// screens — the permission check lives in the router, and a test that
  /// pushed the screen directly would skip it.
  Future<void> pumpApp(
    WidgetTester tester, {
    required AppUser signedInAs,
    List<IngestionSource> initial = const [],
  }) async {
    // A tall surface, because the connect form is longer than a default test
    // viewport and a ListView does not build children it cannot show. Without
    // this, half the form does not exist to be found or tapped.
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    repository = MockSourceRepository(author: signedInAs, initial: initial);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(user: signedInAs),
          ),
          sourceRepositoryProvider.overrideWithValue(repository),
          // The connect form needs squads to assign to, and normally reads
          // them from the shell's snapshot.
          healthSnapshotProvider.overrideWith((ref) => Stream.value(snapshot)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          initialRoute: Routes.ingestionSources,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('reading', () {
    testWidgets('lists each source with its type and when it last synced', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: lead, initial: [source]);

      expect(find.text('Riverpod (demonstration data)'), findsOneWidget);
      expect(find.textContaining('rrousselGit/riverpod'), findsOneWidget);
      expect(find.text('ON'), findsOneWidget);
    });

    testWidgets('an empty list invites the first connection', (tester) async {
      await pumpApp(tester, signedInAs: lead);

      expect(find.text('No sources connected'), findsOneWidget);
      expect(find.text('Connect a source'), findsOneWidget);
    });

    testWidgets('a developer sees the list and cannot open a source', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: developer, initial: [source]);

      expect(find.text('Riverpod (demonstration data)'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });

  group('creating', () {
    testWidgets('a lead connects a new source', (tester) async {
      await pumpApp(tester, signedInAs: lead);

      await tester.tap(find.text('Connect a source'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Ledger repo');
      await tester.enterText(find.byType(TextFormField).at(1), 'acme/ledger');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Platform squad'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect source'));
      await tester.pumpAndSettle();

      expect(repository.sources, hasLength(1));
      expect(repository.sources.single.label, 'Ledger repo');
      expect(repository.sources.single.remoteId, 'acme/ledger');
      expect(repository.sources.single.squadId, 's1');
      // The repository allocates the id, so two people adding at once cannot
      // overwrite each other.
      expect(repository.sources.single.id, isNotEmpty);
    });

    testWidgets('an incomplete form is refused with a message per field', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: lead);

      await tester.tap(find.text('Connect a source'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect source'));
      await tester.pumpAndSettle();

      expect(find.text('Give it a name'), findsOneWidget);
      expect(find.text('Enter the identifier'), findsOneWidget);
      expect(repository.sources, isEmpty);
    });

    testWidgets('the form takes no access token, deliberately', (tester) async {
      // A token box would take a secret, fail to store it, and leave somebody
      // believing they had set it up — `firestore.rules` refuses any source
      // document carrying one.
      await pumpApp(tester, signedInAs: lead);

      await tester.tap(find.text('Connect a source'));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('WHERE THE TOKEN GOES'), findsOneWidget);
    });

    testWidgets('a developer is refused at the route, not just in the UI', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: developer, initial: [source]);

      final context = tester.element(find.byType(Scaffold).first);
      Navigator.of(context).pushNamed(Routes.connectSource);
      await tester.pumpAndSettle();

      expect(find.text('You do not have permission for this'), findsOneWidget);
    });
  });

  group('updating', () {
    testWidgets('opening a source prefills the form with what it holds', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: lead, initial: [source]);

      await tester.tap(find.text('Riverpod (demonstration data)'));
      await tester.pumpAndSettle();

      expect(find.text('Edit source'), findsOneWidget);
      expect(find.text('Riverpod (demonstration data)'), findsOneWidget);
      expect(find.text('rrousselGit/riverpod'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('a changed identifier replaces the source rather than '
        'duplicating it', (tester) async {
      await pumpApp(tester, signedInAs: lead, initial: [source]);

      await tester.tap(find.text('Riverpod (demonstration data)'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(1), 'acme/ledger');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(repository.sources, hasLength(1));
      expect(repository.sources.single.id, 'src1');
      expect(repository.sources.single.remoteId, 'acme/ledger');
      expect(find.text('Source updated.'), findsOneWidget);
    });

    testWidgets('a source can be moved to another squad', (tester) async {
      await pumpApp(tester, signedInAs: lead, initial: [source]);

      await tester.tap(find.text('Riverpod (demonstration data)'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Mobile squad'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(repository.sources.single.squadId, 's2');
    });

    testWidgets('pausing keeps the source instead of forgetting it', (
      tester,
    ) async {
      // A tracker silenced for a fortnight should not have to be retyped,
      // and the scores it already produced stay explainable while it is
      // still there.
      await pumpApp(tester, signedInAs: lead, initial: [source]);

      await tester.tap(find.text('Riverpod (demonstration data)'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Paused'), findsOneWidget);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(repository.sources, hasLength(1));
      expect(repository.sources.single.isEnabled, isFalse);
    });
  });

  group('deleting', () {
    testWidgets('removing asks first, and cancelling changes nothing', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: lead, initial: [source]);

      await tester.tap(find.text('Riverpod (demonstration data)'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmDialog), findsOneWidget);
      expect(find.text('Remove this source?'), findsOneWidget);
      // It names pausing, because that is what somebody who does not want to
      // lose the source actually wants.
      expect(find.textContaining('pause it instead'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.sources, hasLength(1));
    });

    testWidgets('confirming removes it, and the record is gone', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: lead, initial: [source]);

      await tester.tap(find.text('Riverpod (demonstration data)'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(repository.sources, isEmpty);
      expect(find.text('Source removed.'), findsOneWidget);
      // Back on the list, which now has nothing to show.
      expect(find.text('No sources connected'), findsOneWidget);
    });

    testWidgets('a new source offers no remove, because there is nothing '
        'to remove yet', (tester) async {
      await pumpApp(tester, signedInAs: lead);

      await tester.tap(find.text('Connect a source'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });
  });

  group('the confirmation dialog itself', () {
    testWidgets('dismissing without choosing counts as no', (tester) async {
      // The safe reading of "went away" is "did not mean to".
      late bool result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ConfirmDialog.show(
                  context,
                  title: 'Remove this?',
                  body: 'It will be gone.',
                  confirmLabel: 'Remove',
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // Tapping the scrim outside the dialog.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('the confirm button names the action rather than saying OK', (
      tester,
    ) async {
      // A button labelled OK next to a question is the one people tap by
      // reflex, which is the opposite of what a confirmation is for.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: ConfirmDialog(
              title: 'Archive this project?',
              body: 'It comes off the dashboard.',
              confirmLabel: 'Archive',
            ),
          ),
        ),
      );

      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
    });
  });
}
