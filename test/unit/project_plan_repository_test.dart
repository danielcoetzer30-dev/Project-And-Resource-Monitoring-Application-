import 'package:flutter_test/flutter_test.dart';

import 'package:keel/core/errors/exceptions.dart';
import 'package:keel/data/mock_project_plan_repository.dart';
import 'package:keel/models/app_user.dart';
import 'package:keel/models/project_plan.dart';

/// A plan is how a project comes into existence, so this is the one write
/// that decides what the organisation is measured on at all.
///
/// It is also the write that had to be refused when it arrived as a teammate's
/// `createProject` on `ProjectRepository` — not because adding projects is
/// wrong, but because writing them to `projects/` is. These tests pin the
/// shape that works.
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

  ProjectPlan plan({
    String id = '',
    String name = 'Ledger rebuild',
    String client = 'Northbank',
    String squadId = 's1',
    double budgetTotal = 400000,
    double budgetSpent = 120000,
    DateTime? startDate,
    DateTime? endDate,
    double weeklyHours = 120,
  }) {
    return ProjectPlan(
      projectId: id,
      name: name,
      client: client,
      squadId: squadId,
      budgetTotal: budgetTotal,
      budgetSpent: budgetSpent,
      startDate: startDate ?? DateTime.utc(2026, 8, 1),
      endDate: endDate ?? DateTime.utc(2026, 11, 30),
      weeklyHours: weeklyHours,
    );
  }

  group('who may set a project up', () {
    test('a lead adds one and gets an id back', () async {
      final repository = MockProjectPlanRepository(author: lead);
      addTearDown(repository.dispose);

      final id = await repository.save(plan());

      expect(id, isNotEmpty);
      expect(repository.plans.single.name, 'Ledger rebuild');
      expect(repository.plans.single.projectId, id);
    });

    test('a developer is refused, and nothing is written', () async {
      final repository = MockProjectPlanRepository(author: developer);
      addTearDown(repository.dispose);

      await expectLater(
        repository.save(plan()),
        throwsA(isA<PermissionException>()),
      );

      expect(repository.plans, isEmpty);
    });

    test('signed out is refused', () async {
      final repository = MockProjectPlanRepository();
      addTearDown(repository.dispose);

      await expectLater(repository.save(plan()), throwsA(isA<AuthException>()));
    });
  });

  group('what counts as a usable plan', () {
    test('a project needs a name', () {
      expect(ProjectPlanRules.nameProblem('  '), contains('name'));
      expect(ProjectPlanRules.nameProblem('Ledger rebuild'), isNull);
    });

    test('a project needs a squad, or it is created and never scored', () {
      // Activity arrives attributed to a squad. A project without one would
      // appear on the dashboard and stay at its starting score forever, which
      // looks exactly like a project nobody is working on.
      final problem = ProjectPlanRules.problemWith(plan(squadId: ''));

      expect(problem, contains('squad'));
    });

    test('the end date has to be after the start', () {
      final problem = ProjectPlanRules.problemWith(
        plan(
          startDate: DateTime.utc(2026, 11, 30),
          endDate: DateTime.utc(2026, 8, 1),
        ),
      );

      expect(problem, contains('after'));
    });

    test('spending more than the budget is allowed', () {
      // An overrun is the thing worth reporting, not an input error. Refusing
      // it would make the one project that most needs a warning unsaveable.
      expect(
        ProjectPlanRules.problemWith(
          plan(budgetTotal: 100000, budgetSpent: 140000),
        ),
        isNull,
      );
    });

    test('negative money is refused', () {
      expect(
        ProjectPlanRules.problemWith(plan(budgetSpent: -1)),
        contains('negative'),
      );
    });

    test('an invalid plan is never stored', () async {
      final repository = MockProjectPlanRepository(author: lead);
      addTearDown(repository.dispose);

      await expectLater(
        repository.save(plan(name: '')),
        throwsA(isA<ValidationException>()),
      );

      expect(repository.plans, isEmpty);
    });
  });

  group('a half-filled plan still works', () {
    test('a project with no budget or dates is saveable but not usable', () {
      // Ingestion scores it on what is known. The alternative — refusing to
      // save until every figure is in — would mean a team cannot start
      // tracking a project until its finance paperwork is done.
      const sparse = ProjectPlan(projectId: '', name: 'Spike', squadId: 's1');

      expect(ProjectPlanRules.problemWith(sparse), isNull);
      expect(sparse.isUsable, isFalse);
    });
  });

  group('archiving', () {
    test('archiving keeps the plan rather than removing it', () async {
      final repository = MockProjectPlanRepository(author: lead);
      addTearDown(repository.dispose);

      final id = await repository.save(plan());
      await repository.setArchived(projectId: id, archived: true);

      // There is no delete. Removing a failing project is the simplest way to
      // make it stop looking bad, and the history is the research record.
      expect(repository.plans, hasLength(1));
      expect(repository.plans.single.isArchived, isTrue);
    });

    test('an archived project can be brought back', () async {
      final repository = MockProjectPlanRepository(author: lead);
      addTearDown(repository.dispose);

      final id = await repository.save(plan());
      await repository.setArchived(projectId: id, archived: true);
      await repository.setArchived(projectId: id, archived: false);

      expect(repository.plans.single.isArchived, isFalse);
    });

    test('a developer cannot archive', () async {
      final repository = MockProjectPlanRepository(
        author: developer,
        initial: [plan(id: 'p1')],
      );
      addTearDown(repository.dispose);

      await expectLater(
        repository.setArchived(projectId: 'p1', archived: true),
        throwsA(isA<PermissionException>()),
      );

      expect(repository.plans.single.isArchived, isFalse);
    });
  });

  test('saving twice updates rather than duplicating', () async {
    final repository = MockProjectPlanRepository(author: lead);
    addTearDown(repository.dispose);

    final id = await repository.save(plan());
    await repository.save(plan(id: id, name: 'Ledger rebuild II'));

    expect(repository.plans, hasLength(1));
    expect(repository.plans.single.name, 'Ledger rebuild II');
  });
}
