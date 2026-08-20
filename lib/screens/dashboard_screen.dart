import 'package:flutter/material.dart';

import '../data/project_repository.dart';
import '../models/health_state.dart';
import '../models/project.dart';
import '../models/squad.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/health_seam.dart';
import '../widgets/panel.dart';
import '../widgets/status_pill.dart';
import 'project_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final worst = snapshot.worstFirst;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        Tokens.space2,
        Tokens.space4,
        Tokens.space7,
      ),
      children: [
        _PortfolioSummary(snapshot: snapshot),
        const SizedBox(height: Tokens.space4),
        if (snapshot.grid.isShedding) ...[
          _GridStrip(grid: snapshot.grid),
          const SizedBox(height: Tokens.space4),
        ],
        Padding(
          padding: const EdgeInsets.only(
            left: Tokens.space1,
            bottom: Tokens.space3,
          ),
          child: Text('NEEDS ATTENTION FIRST', style: AppType.label),
        ),
        for (final project in worst) ...[
          _ProjectRow(project: project, snapshot: snapshot),
          const SizedBox(height: Tokens.space3),
        ],
      ],
    );
  }
}

class _PortfolioSummary extends StatelessWidget {
  const _PortfolioSummary({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final needsAction = snapshot.projects
        .where((p) => p.state.severity >= HealthState.atRisk.severity)
        .length;

    return Panel(
      title: 'Portfolio',
      trailing: Text(
        '${snapshot.projects.length} active',
        style: AppType.data,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$needsAction', style: AppType.metric),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Text(
                  needsAction == 1
                      ? 'project needs action now'
                      : 'projects need action now',
                  style: AppType.bodyMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          Row(
            children: [
              for (final state in HealthState.values)
                Expanded(
                  child: _StateCount(
                    state: state,
                    count: snapshot.countIn(state),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateCount extends StatelessWidget {
  const _StateCount({required this.state, required this.count});

  final HealthState state;
  final int count;

  @override
  Widget build(BuildContext context) {
    final dim = count == 0;
    return Semantics(
      label: '$count ${state.label}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            margin: const EdgeInsets.only(right: Tokens.space2),
            color: dim ? Tokens.rule : state.color,
          ),
          const SizedBox(height: Tokens.space2),
          Text(
            '$count',
            style: AppType.metricSmall.copyWith(
              color: dim ? Tokens.slate : Tokens.chalk,
            ),
          ),
          const SizedBox(height: Tokens.space1),
          Text(
            state.label,
            style: AppType.label.copyWith(letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

/// Grid state gets its own strip, above the projects.
///
/// Placing it here is the point: when the power is out, that is the first
/// thing explaining today's numbers, and no project should be read without it.
class _GridStrip extends StatelessWidget {
  const _GridStrip({required this.grid});

  final GridStatus grid;

  @override
  Widget build(BuildContext context) {
    final next = grid.nextOutageStart;
    return Container(
      padding: const EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.brass.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.brass.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bolt_outlined, size: 18, color: Tokens.brass),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stage ${grid.stage} load-shedding',
                  style: AppType.bodyStrong,
                ),
                const SizedBox(height: Tokens.space1),
                Text(
                  next == null
                      ? '${grid.hoursLostThisWeek} hours lost this week. Capacity forecasts already account for it.'
                      : 'Next outage ${_time(next)}–${_time(grid.nextOutageEnd!)}. '
                          '${grid.hoursLostThisWeek} hours lost this week, excluded from every health score.',
                  style: AppType.bodyMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.snapshot});

  final Project project;
  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.seam,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(
              project: project,
              squad: _squadFor(project.squadId),
            ),
          ),
        ),
        focusColor: Tokens.beacon.withValues(alpha: 0.18),
        child: Container(
          padding: const EdgeInsets.all(Tokens.space4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            border: Border.all(color: Tokens.rule, width: Tokens.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name, style: AppType.heading),
                        const SizedBox(height: Tokens.space1),
                        Text(project.client, style: AppType.bodyMuted),
                      ],
                    ),
                  ),
                  const SizedBox(width: Tokens.space3),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        project.score.round().toString(),
                        style: AppType.metricSmall
                            .copyWith(color: project.state.color),
                      ),
                      const SizedBox(height: Tokens.space1),
                      Text('SCORE', style: AppType.label),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Tokens.space4),
              HealthSeam(segments: project.seam),
              const SizedBox(height: Tokens.space3),
              Row(
                children: [
                  StatusPill(state: project.state),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: Text(
                      _summary(project),
                      style: AppType.data,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Squad? _squadFor(String id) {
    for (final squad in snapshot.squads) {
      if (squad.id == id) return squad;
    }
    return null;
  }

  static String _summary(Project p) {
    final parts = <String>[
      '${(p.budgetBurn * 100).round()}% burn',
      '${p.scheduleDaysRemaining}d left',
      if (p.openSignals > 0) '${p.openSignals} signals',
    ];
    return parts.join('  ·  ');
  }
}
