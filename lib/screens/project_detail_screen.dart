import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/squad.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/health_seam.dart';
import '../widgets/panel.dart';
import '../widgets/status_pill.dart';

/// Where a score stops being a verdict and becomes an explanation.
///
/// The factor breakdown is the reason this screen exists: a team told only
/// "you are at 28" can argue with the number but cannot act on it.
class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.squad,
  });

  final Project project;
  final Squad? squad;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(project.name, style: AppType.heading),
        leading: const BackButton(color: Tokens.slate),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          Tokens.space2,
          Tokens.space4,
          Tokens.space7,
        ),
        children: [
          _ScorePanel(project: project),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'Health history',
            child: HealthSeam(
              segments: project.seam,
              height: 40,
              showAxis: true,
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Panel(
            title: 'What is driving the score',
            child: Column(
              children: [
                for (var i = 0; i < project.factors.length; i++) ...[
                  if (i > 0) const SizedBox(height: Tokens.space4),
                  _FactorRow(factor: project.factors[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: Tokens.space4),
          _DeliveryPanel(project: project),
          if (squad != null) ...[
            const SizedBox(height: Tokens.space4),
            _SquadPanel(squad: squad!),
          ],
        ],
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: project.client,
      trailing: StatusPill(state: project.state),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            project.score.round().toString(),
            style: AppType.metric.copyWith(
              fontSize: 46,
              color: project.state.color,
            ),
          ),
          const SizedBox(width: Tokens.space2),
          Text('/ 100', style: AppType.bodyMuted),
          const Spacer(),
          if (project.openSignals > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${project.openSignals}', style: AppType.metricSmall),
                const SizedBox(height: Tokens.space1),
                Text('OPEN SIGNALS', style: AppType.label),
              ],
            ),
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor});

  final HealthFactor factor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${factor.name}: ${factor.value.round()} out of 100, '
          '${factor.state.label}. ${factor.detail}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(factor.name, style: AppType.bodyStrong)),
              const SizedBox(width: Tokens.space2),
              Text(
                '${(factor.weight * 100).round()}% weight',
                style: AppType.data,
              ),
            ],
          ),
          const SizedBox(height: Tokens.space2),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  child: LinearProgressIndicator(
                    value: factor.value / 100,
                    minHeight: 6,
                    backgroundColor: Tokens.shaft,
                    valueColor: AlwaysStoppedAnimation(factor.state.color),
                  ),
                ),
              ),
              const SizedBox(width: Tokens.space3),
              SizedBox(
                width: 28,
                child: Text(
                  factor.value.round().toString(),
                  style: AppType.dataStrong,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space2),
          Text(factor.detail, style: AppType.bodyMuted),
        ],
      ),
    );
  }
}

class _DeliveryPanel extends StatelessWidget {
  const _DeliveryPanel({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Delivery',
      child: Column(
        children: [
          _MetricLine(
            label: 'Budget consumed',
            value: '${(project.budgetBurn * 100).round()}%',
            emphasis: project.budgetBurn > 0.85,
          ),
          const SizedBox(height: Tokens.space3),
          _MetricLine(
            label: 'Days of schedule left',
            value: '${project.scheduleDaysRemaining}',
            emphasis: project.scheduleDaysRemaining < 15,
          ),
          const SizedBox(height: Tokens.space3),
          _MetricLine(
            label: 'Hours lost to outages',
            value: '${project.loadSheddingHoursLost.toStringAsFixed(1)}h',
          ),
          const SizedBox(height: Tokens.space3),
          const Divider(height: Tokens.hairline),
          const SizedBox(height: Tokens.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bolt_outlined, size: 16, color: Tokens.slate),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Text(
                  'Outage hours are reported, never deducted. The score above '
                  'measures delivery, not the grid.',
                  style: AppType.bodyMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppType.body)),
        Text(
          value,
          style: emphasis
              ? AppType.metricSmall.copyWith(fontSize: 16, color: Tokens.ember)
              : AppType.dataStrong,
        ),
      ],
    );
  }
}

class _SquadPanel extends StatelessWidget {
  const _SquadPanel({required this.squad});

  final Squad squad;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Assigned squad',
      trailing: StatusPill(state: squad.state, compact: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(squad.name, style: AppType.heading),
          const SizedBox(height: Tokens.space2),
          Text(
            '${squad.headcount} people  ·  ${squad.capacityLabel} of capacity '
            'committed across ${squad.activeProjectCount} '
            '${squad.activeProjectCount == 1 ? 'project' : 'projects'}',
            style: AppType.bodyMuted,
          ),
        ],
      ),
    );
  }
}
