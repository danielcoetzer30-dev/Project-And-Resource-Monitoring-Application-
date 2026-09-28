import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/project_repository.dart';
import '../models/health_state.dart';
import '../models/project.dart';

/// How the dashboard is currently ordered.
enum ProjectSort {
  worstFirst('Worst first'),
  nameAscending('Name'),
  deadlineSoonest('Deadline');

  const ProjectSort(this.label);

  final String label;
}

/// Filtering and ordering applied to the dashboard.
class DashboardView {
  const DashboardView({
    this.sort = ProjectSort.worstFirst,
    this.statesShown = const {},
    this.query = '',
  });

  final ProjectSort sort;

  /// Empty means show everything. Non-empty filters to those states.
  final Set<HealthState> statesShown;

  final String query;

  bool get isFiltered => statesShown.isNotEmpty || query.isNotEmpty;

  DashboardView copyWith({
    ProjectSort? sort,
    Set<HealthState>? statesShown,
    String? query,
  }) {
    return DashboardView(
      sort: sort ?? this.sort,
      statesShown: statesShown ?? this.statesShown,
      query: query ?? this.query,
    );
  }

  /// Applies this view to a snapshot's projects.
  ///
  /// Worst-first is the default deliberately: in an early warning system the
  /// thing needing attention belongs at the top, not wherever the alphabet
  /// happens to put it.
  List<Project> apply(List<Project> projects) {
    var result = projects;

    if (statesShown.isNotEmpty) {
      result = result.where((p) => statesShown.contains(p.state)).toList();
    }

    if (query.isNotEmpty) {
      final needle = query.toLowerCase();
      result = result
          .where(
            (p) =>
                p.name.toLowerCase().contains(needle) ||
                p.client.toLowerCase().contains(needle),
          )
          .toList();
    } else {
      result = [...result];
    }

    switch (sort) {
      case ProjectSort.worstFirst:
        result.sort((a, b) {
          final bySeverity = b.state.severity.compareTo(a.state.severity);
          return bySeverity != 0 ? bySeverity : a.score.compareTo(b.score);
        });
      case ProjectSort.nameAscending:
        result.sort((a, b) => a.name.compareTo(b.name));
      case ProjectSort.deadlineSoonest:
        result.sort(
          (a, b) => a.scheduleDaysRemaining.compareTo(b.scheduleDaysRemaining),
        );
    }

    return result;
  }
}

/// Owns dashboard presentation state.
///
/// Note it holds no project data. The snapshot comes from the repository
/// through its own provider; this only decides how it is shown, so a change of
/// sort order does not re-fetch anything.
class DashboardNotifier extends Notifier<DashboardView> {
  @override
  DashboardView build() => const DashboardView();

  void setSort(ProjectSort sort) => state = state.copyWith(sort: sort);

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggleState(HealthState healthState) {
    final next = {...state.statesShown};
    if (!next.remove(healthState)) next.add(healthState);
    state = state.copyWith(statesShown: next);
  }

  void clearFilters() => state = const DashboardView();
}

/// Convenience for screens: the filtered, sorted list ready to render.
List<Project> visibleProjects(HealthSnapshot snapshot, DashboardView view) =>
    view.apply(snapshot.projects);
