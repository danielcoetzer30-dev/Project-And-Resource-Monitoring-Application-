import 'package:flutter/material.dart';

import '../data/project_repository.dart';
import '../models/health_state.dart';
import '../models/project.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/dashboard/dashboard_format.dart';
import '../widgets/dashboard/grid_strip.dart';
import '../widgets/dashboard/project_row.dart';
import '../widgets/dashboard/signals_panel.dart';
import '../widgets/dashboard/summary_strip.dart';
import '../widgets/dashboard/sync_banner.dart';
import '../widgets/panel.dart';

/// How the project list is ordered.
enum _Sort {
  worstFirst('Worst first'),
  nameAscending('Name'),
  deadlineSoonest('Deadline');

  const _Sort(this.label);

  final String label;
}

/// Where the team lands: every project, worst first, with the signals behind
/// the scores and the grid as context.
///
/// Read-only by design. There is no control here for typing in progress; the
/// only input is *Connect a source*, handed in as a callback so this screen
/// never needs to know the router.
///
/// Sort and filter live in this widget's state rather than in a provider. The
/// shell keeps every tab mounted in an IndexedStack, so the choice survives
/// switching tabs. When the Riverpod state layer arrives, replace [_sort] and
/// [_states] with DashboardNotifier and nothing else here has to change.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.snapshot,
    this.onOpenProject,
    this.onConnectSource,
  });

  final HealthSnapshot snapshot;

  /// Called when a project row is tapped. Null leaves rows non-navigating.
  final ValueChanged<Project>? onOpenProject;

  /// Called from the empty state. Null hides the button.
  final VoidCallback? onConnectSource;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _Sort _sort = _Sort.worstFirst;

  /// Empty means show everything.
  final Set<HealthState> _states = {};

  /// Worst-first is the default deliberately: in an early warning system the
  /// thing needing attention belongs at the top, not wherever the alphabet
  /// happens to put it.
  List<Project> _apply(List<Project> projects) {
    final result = _states.isEmpty
        ? [...projects]
        : projects.where((p) => _states.contains(p.state)).toList();

    switch (_sort) {
      case _Sort.worstFirst:
        result.sort((a, b) {
          final bySeverity = b.state.severity.compareTo(a.state.severity);
          return bySeverity != 0 ? bySeverity : a.score.compareTo(b.score);
        });
      case _Sort.nameAscending:
        result.sort((a, b) => a.name.compareTo(b.name));
      case _Sort.deadlineSoonest:
        result.sort(
          (a, b) => a.scheduleDaysRemaining.compareTo(b.scheduleDaysRemaining),
        );
    }
    return result;
  }

  void _toggleState(HealthState state) {
    setState(() {
      if (!_states.remove(state)) _states.add(state);
    });
  }

  void _clearFilters() => setState(_states.clear);

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final visible = _apply(snapshot.projects);
    final squadNames = {for (final s in snapshot.squads) s.id: s.name};
    final projectNames = {for (final p in snapshot.projects) p.id: p.name};

    final banner = snapshot.isLive
        ? null
        : 'Showing cached data from ${clockTime(snapshot.capturedAt)}. It '
              'refreshes when the connection returns.';

    final projects = _ProjectsSection(
      all: snapshot.projects,
      visible: visible,
      isFiltered: _states.isNotEmpty,
      sort: _sort,
      squadNames: squadNames,
      onOpenProject: widget.onOpenProject,
      onConnectSource: widget.onConnectSource,
      onSort: (sort) => setState(() => _sort = sort),
      onClearFilters: _clearFilters,
    );

    final signals = SignalsPanel(
      signals: snapshot.signals,
      projectNames: projectNames,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;

        return ListView(
          padding: const EdgeInsets.all(Tokens.space4),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'Where your projects stand right now, and what is '
                    'changing.',
                    style: AppType.bodyMuted,
                  ),
                ),
                const SizedBox(width: Tokens.space3),
                Text(
                  'Updated ${clockTime(snapshot.capturedAt)}',
                  style: AppType.data,
                ),
              ],
            ),
            const SizedBox(height: Tokens.space4),
            if (banner != null) ...[
              SyncBanner(message: banner),
              const SizedBox(height: Tokens.space3),
            ],
            GridStrip(grid: snapshot.grid),
            const SizedBox(height: Tokens.space3),
            SummaryStrip(
              projects: snapshot.projects,
              selected: _states,
              onToggle: _toggleState,
            ),
            const SizedBox(height: Tokens.space4),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: projects),
                  const SizedBox(width: Tokens.space4),
                  Expanded(flex: 2, child: signals),
                ],
              )
            else ...[
              projects,
              const SizedBox(height: Tokens.space4),
              signals,
            ],
          ],
        );
      },
    );
  }
}

class _ProjectsSection extends StatelessWidget {
  const _ProjectsSection({
    required this.all,
    required this.visible,
    required this.isFiltered,
    required this.sort,
    required this.squadNames,
    required this.onOpenProject,
    required this.onConnectSource,
    required this.onSort,
    required this.onClearFilters,
  });

  final List<Project> all;
  final List<Project> visible;
  final bool isFiltered;
  final _Sort sort;
  final Map<String, String> squadNames;
  final ValueChanged<Project>? onOpenProject;
  final VoidCallback? onConnectSource;
  final ValueChanged<_Sort> onSort;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) {
      return _EmptyPanel(
        icon: Icons.hub_outlined,
        title: 'No projects yet',
        body:
            'Connect a repository or task tracker and your first health '
            'score appears here, with nobody typing in an update.',
        actionLabel: onConnectSource == null ? null : 'Connect a source',
        onAction: onConnectSource,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Showing ${visible.length} of ${all.length}',
                style: AppType.data,
              ),
            ),
            if (isFiltered)
              TextButton(
                onPressed: onClearFilters,
                style: TextButton.styleFrom(
                  foregroundColor: Tokens.beacon,
                  textStyle: AppType.bodyStrong,
                ),
                child: const Text('Clear filters'),
              ),
            PopupMenuButton<_Sort>(
              tooltip: 'Change sort order',
              color: Tokens.seam,
              initialValue: sort,
              onSelected: onSort,
              itemBuilder: (_) => [
                for (final option in _Sort.values)
                  PopupMenuItem(
                    value: option,
                    child: Text(option.label, style: AppType.body),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sort: ${sort.label}',
                      style: AppType.bodyStrong.copyWith(color: Tokens.beacon),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Tokens.beacon),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.space2),
        if (visible.isEmpty)
          _EmptyPanel(
            icon: Icons.filter_alt_off_outlined,
            title: 'No projects match these filters',
            body: 'Clear the filters to see every project again.',
            actionLabel: 'Clear filters',
            onAction: onClearFilters,
          )
        else
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: Tokens.space3),
            ProjectRow(
              project: visible[i],
              squadName: squadNames[visible[i].squadId],
              onTap: onOpenProject == null
                  ? null
                  : () => onOpenProject!(visible[i]),
            ),
          ],
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(Tokens.space5),
      child: Column(
        children: [
          Icon(icon, size: 24, color: Tokens.slate),
          const SizedBox(height: Tokens.space3),
          Text(title, style: AppType.heading, textAlign: TextAlign.center),
          const SizedBox(height: Tokens.space2),
          Text(body, style: AppType.bodyMuted, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Tokens.space4),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: Tokens.beacon,
                foregroundColor: Tokens.shaft,
                textStyle: AppType.bodyStrong,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
