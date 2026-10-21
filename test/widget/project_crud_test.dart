import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel/data/mock_project_plan_repository.dart';
import 'package:keel/data/project_repository.dart';
import 'package:keel/models/app_user.dart';
import 'package:keel/models/project_plan.dart';
import 'package:keel/models/squad.dart';
import 'package:keel/routing/app_router.dart';
import 'package:keel/routing/routes.dart';
import 'package:keel/state/providers.dart';
import 'package:keel/theme/app_theme.dart';
import 'package:keel/widgets/confirm_dialog.dart';

import '../support/fake_auth_repository.dart';

/// Project setup, end to end: list, open, change, archive.
///
/// Archiving is this module's delete, and the tests below are what hold that
/// position in place: the plan survives, the person is asked first, and the
/// screen says what happened. A permanent delete would be the easiest way to
/// make a failing project stop looking bad, which is the behaviour the
/// anti-gaming argument exists to resist.
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

  final plan = ProjectPlan(
    projectId: 'p1',
    name: 'Ledger rebuild',
    client: 'Northbank',
    squadId: 's1',
    budgetTotal: 400000,
    budgetSpent: 120000,
    startDate: DateTime.utc(2026, 8, 1),
    endDate: DateTime.utc(2026, 11, 30),
    weeklyHours: 120,
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

  /// The save button says what it will do: adding and editing are the same
  /// form, so the label is the only thing that differs.
  const addLabel = 'Add project';
  const saveLabel = 'Save changes';

  late MockProjectPlanRepository repository;

  Future<void> pumpApp(
    WidgetTester tester, {
    required AppUser signedInAs,
    List<ProjectPlan> initial = const [],
  }) async {
    // A tall surface: the project form is longer than a default test viewport
    // and a ListView does not build children it cannot show.
    tester.view.physicalSize = const Size(1000, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    repository = MockProjectPlanRepository(
      author: signedInAs,
      initial: initial,
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(user: signedInAs),
          ),
          projectPlanRepositoryProvider.overrideWithValue(repository),
          healthSnapshotProvider.overrideWith((ref) => Stream.value(snapshot)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          initialRoute: Routes.projects,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('reading', () {
    testWidgets('lists each project with its client', (tester) async {
      await pumpApp(tester, signedInAs: lead, initial: [plan]);

      expect(find.text('Ledger rebuild'), findsOneWidget);
      expect(find.text('Northbank'), findsOneWidget);
    });

    testWidgets('an incomplete plan says it is scored on less', (tester) async {
      // A plan missing a budget or a schedule still scores, just on less.
      // Knowing which is which is the difference between a low score and an
      // incomplete one.
      await pumpApp(
        tester,
        signedInAs: lead,
        initial: const [
          ProjectPlan(projectId: 'p2', name: 'Spike', squadId: 's1'),
        ],
      );

      expect(
        find.textContaining('Budget, dates or hours missing'),
        findsOneWidget,
      );
    });

    testWidgets('archived projects are kept, under their own heading', (
      tester,
    ) async {
      await pumpApp(
        tester,
        signedInAs: lead,
        initial: [plan.copyWith(isArchived: true)],
      );

      expect(find.text('ARCHIVED'), findsOneWidget);
      expect(find.text('Ledger rebuild'), findsOneWidget);
    });

    testWidgets('a developer sees every project and opens none', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: developer, initial: [plan]);

      expect(find.text('Ledger rebuild'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text('Add'), findsNothing);
    });
  });

  group('creating and updating', () {
    testWidgets('a lead adds a project and is told what happens next', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: lead);

      await tester.tap(find.text('Add a project'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'New build');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Platform squad'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(addLabel));
      await tester.pumpAndSettle();

      expect(repository.plans, hasLength(1));
      expect(repository.plans.single.name, 'New build');
      expect(repository.plans.single.squadId, 's1');
      // Honest about the delay rather than looking like a failed save.
      expect(
        find.textContaining('appears on the dashboard after the next'),
        findsOneWidget,
      );
    });

    testWidgets('a project with no name is refused', (tester) async {
      await pumpApp(tester, signedInAs: lead);

      await tester.tap(find.text('Add a project'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(addLabel));
      await tester.pumpAndSettle();

      expect(repository.plans, isEmpty);
    });

    testWidgets('opening a project prefills the form and saves changes', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: lead, initial: [plan]);

      await tester.tap(find.text('Ledger rebuild'));
      await tester.pumpAndSettle();

      expect(find.text('Ledger rebuild'), findsWidgets);
      expect(find.text('Northbank'), findsWidgets);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Ledger rebuild II',
      );
      await tester.tap(find.text(saveLabel));
      await tester.pumpAndSettle();

      expect(repository.plans, hasLength(1));
      expect(repository.plans.single.name, 'Ledger rebuild II');
      expect(find.text('Changes saved.'), findsOneWidget);
    });
  });

  group('archiving, which is this module\'s delete', () {
    testWidgets('archiving asks first, and cancelling changes nothing', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: lead, initial: [plan]);

      await tester.tap(find.text('Ledger rebuild'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Archive project'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmDialog), findsOneWidget);
      expect(find.text('Archive this project?'), findsOneWidget);
      // The dialog has to say nothing is lost, or it reads as a delete.
      expect(find.textContaining('Nothing is deleted'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.plans.single.isArchived, isFalse);
    });

    testWidgets('confirming archives the project and keeps the plan', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: lead, initial: [plan]);

      await tester.tap(find.text('Ledger rebuild'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Archive project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      // Kept, not removed. There is no delete, and the history is the
      // research record.
      expect(repository.plans, hasLength(1));
      expect(repository.plans.single.isArchived, isTrue);
      expect(find.text('Project archived.'), findsOneWidget);
    });

    testWidgets('bringing a project back is not confirmed, because it '
        'destroys nothing', (tester) async {
      await pumpApp(
        tester,
        signedInAs: lead,
        initial: [plan.copyWith(isArchived: true)],
      );

      await tester.tap(find.text('Ledger rebuild'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bring back'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmDialog), findsNothing);
      expect(repository.plans.single.isArchived, isFalse);
    });

    testWidgets('there is no permanent delete anywhere on the form', (
      tester,
    ) async {
      // If a delete control ever appears here, this fails — and it should.
      // Removing a failing project is the simplest possible way to make it
      // stop looking bad.
      await pumpApp(tester, signedInAs: lead, initial: [plan]);

      await tester.tap(find.text('Ledger rebuild'));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsNothing);
      expect(find.text('Delete project'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
    });

    testWidgets('a developer reaching the form is refused at the route', (
      tester,
    ) async {
      await pumpApp(tester, signedInAs: developer, initial: [plan]);

      final context = tester.element(find.byType(Scaffold).first);
      Navigator.of(context).pushNamed(Routes.editProject, arguments: 'p1');
      await tester.pumpAndSettle();

      expect(find.text('You do not have permission for this'), findsOneWidget);
    });
  });
}
