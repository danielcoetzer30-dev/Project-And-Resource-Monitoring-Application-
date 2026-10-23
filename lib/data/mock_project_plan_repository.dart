import 'dart:async';

import '../core/errors/exceptions.dart';
import '../models/app_user.dart';
import '../models/project_plan.dart';
import 'project_plan_repository.dart';

/// An in-memory [ProjectPlanRepository], for tests and for running with no
/// backend.
///
/// Applies the same two refusals as the real one (role, then validity), so a
/// test that passes here cannot rely on something Firestore would reject.
class MockProjectPlanRepository implements ProjectPlanRepository {
  MockProjectPlanRepository({
    this.author,
    List<ProjectPlan> initial = const [],
  }) {
    _plans.addAll(initial);
  }

  /// Who writes are made as. Null stands for signed out, which cannot write.
  final AppUser? author;

  final _plans = <ProjectPlan>[];
  final _changed = StreamController<List<ProjectPlan>>.broadcast();

  var _nextId = 0;

  /// What is stored, for a test to assert on.
  List<ProjectPlan> get plans => List.unmodifiable(_plans);

  @override
  Stream<List<ProjectPlan>> watch() {
    // Stream.multi, not async*: a listener gets the current value at once and
    // every change after it, which is how Firestore's snapshots() behaves.
    return Stream<List<ProjectPlan>>.multi((controller) {
      controller.add(List.unmodifiable(_plans));
      final subscription = _changed.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<ProjectPlan?> watchOne(String projectId) =>
      watch().map((plans) => _find(plans, projectId));

  @override
  Future<String> save(ProjectPlan plan) async {
    _refuseUnlessPermitted();

    final problem = ProjectPlanRules.problemWith(plan);
    if (problem != null) throw ValidationException(problem);

    final id = plan.projectId.isEmpty ? 'plan-${++_nextId}' : plan.projectId;
    final saved = ProjectPlan(
      projectId: id,
      name: plan.name,
      client: plan.client,
      squadId: plan.squadId,
      budgetTotal: plan.budgetTotal,
      budgetSpent: plan.budgetSpent,
      startDate: plan.startDate,
      endDate: plan.endDate,
      weeklyHours: plan.weeklyHours,
      isArchived: plan.isArchived,
    );

    final index = _plans.indexWhere((p) => p.projectId == id);
    if (index >= 0) {
      _plans[index] = saved;
    } else {
      _plans.add(saved);
    }

    _emit();
    return id;
  }

  @override
  Future<void> setArchived({
    required String projectId,
    required bool archived,
  }) async {
    _refuseUnlessPermitted();

    final index = _plans.indexWhere((p) => p.projectId == projectId);
    if (index < 0) return;

    _plans[index] = _plans[index].copyWith(isArchived: archived);
    _emit();
  }

  static ProjectPlan? _find(List<ProjectPlan> plans, String projectId) {
    for (final plan in plans) {
      if (plan.projectId == projectId) return plan;
    }
    return null;
  }

  void _emit() {
    if (!_changed.isClosed) _changed.add(List.unmodifiable(_plans));
  }

  void _refuseUnlessPermitted() {
    if (author == null) {
      throw const AuthException('Sign in to change a project.');
    }
    if (!author!.canChangeSettings) {
      throw const PermissionException(
        'Only leads and managers can add or change a project.',
      );
    }
  }

  void dispose() => _changed.close();
}
