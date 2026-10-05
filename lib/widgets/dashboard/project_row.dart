import 'package:flutter/material.dart';

import '../../../models/project.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../health_seam.dart';
import '../status_pill.dart';
import 'dashboard_format.dart';

/// One project on the dashboard.
///
/// Reads top to bottom as: what is it, how is it, how did it get here, and
/// what is going on around it. The seam sits in the middle because trajectory
/// is the point of an early warning system; the score alone is a snapshot.
class ProjectRow extends StatelessWidget {
  const ProjectRow({
    super.key,
    required this.project,
    this.squadName,
    this.onTap,
  });

  final Project project;

  /// Shown beside the client. A squad name, never a person.
  final String? squadName;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = project;
    final state = p.state;
    final subtitle = squadName == null ? p.client : '${p.client} · $squadName';

    // The row needs its own Material rather than a Panel: a Panel paints an
    // opaque surface, which would hide the ink ripple underneath it.
    return Material(
      color: Tokens.seam,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        side: const BorderSide(color: Tokens.rule, width: Tokens.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: AppType.heading),
                        const SizedBox(height: Tokens.space1),
                        Text(subtitle, style: AppType.bodyMuted),
                      ],
                    ),
                  ),
                  const SizedBox(width: Tokens.space3),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${p.score.round()}',
                        style: AppType.metricSmall.copyWith(color: state.color),
                      ),
                      const SizedBox(height: Tokens.space2),
                      StatusPill(state: state),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Tokens.space3),
              HealthSeam(segments: p.seam),
              const SizedBox(height: Tokens.space3),
              Wrap(
                spacing: Tokens.space4,
                runSpacing: Tokens.space2,
                children: [
                  _Fact(
                    icon: Icons.notifications_none_outlined,
                    text: plural(p.openSignals, 'open signal'),
                  ),
                  _Fact(
                    icon: Icons.schedule,
                    text: '${plural(p.scheduleDaysRemaining, 'day')} left',
                  ),
                  _Fact(
                    icon: Icons.payments_outlined,
                    text: '${(p.budgetBurn * 100).round()}% of budget used',
                  ),
                  if (p.loadSheddingHoursLost > 0)
                    _Fact(
                      icon: Icons.bolt_outlined,
                      text:
                          '${hoursLabel(p.loadSheddingHoursLost)} lost to '
                          'outages, not scored',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Tokens.slate),
        const SizedBox(width: Tokens.space1),
        Text(text, style: AppType.data),
      ],
    );
  }
}
