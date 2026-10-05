import 'package:flutter/material.dart';

import '../data/project_repository.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/panel.dart';

/// The screen no competing tool has.
///
/// Its job is to hold infrastructure loss separate from delivery performance,
/// so a team is never scored down for a national power failure.
class InfrastructureScreen extends StatelessWidget {
  const InfrastructureScreen({super.key, required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final grid = snapshot.grid;
    final totalLost = snapshot.projects.fold<double>(
      0,
      (sum, p) => sum + p.loadSheddingHoursLost,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        Tokens.space2,
        Tokens.space4,
        Tokens.space7,
      ),
      children: [
        Panel(
          title: 'Grid status',
          trailing: Text(
            grid.isShedding ? 'SHEDDING' : 'STABLE',
            style: AppType.label.copyWith(
              color: grid.isShedding ? Tokens.brass : Tokens.jade,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    grid.isShedding ? 'Stage ${grid.stage}' : 'No shedding',
                    style: AppType.metric.copyWith(
                      color: grid.isShedding ? Tokens.brass : Tokens.jade,
                    ),
                  ),
                ],
              ),
              if (grid.nextOutageStart != null) ...[
                const SizedBox(height: Tokens.space3),
                Text(
                  'Next outage ${_time(grid.nextOutageStart!)}–${_time(grid.nextOutageEnd!)}',
                  style: AppType.body,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Tokens.space4),
        Panel(
          title: 'Hours lost this week',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(totalLost.toStringAsFixed(1), style: AppType.metric),
                  const SizedBox(width: Tokens.space2),
                  Text('hours', style: AppType.bodyMuted),
                ],
              ),
              const SizedBox(height: Tokens.space4),
              for (final p in snapshot.projects) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: Tokens.space3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          style: AppType.body,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Tokens.space3),
                      Text(
                        '${p.loadSheddingHoursLost.toStringAsFixed(1)}h',
                        style: AppType.dataStrong,
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: Tokens.space4),
              const SizedBox(height: Tokens.space3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: Tokens.slate,
                  ),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: Text(
                      'These hours are excluded from every health score. '
                      'Outages change what a team could deliver, not how well '
                      'they delivered it.',
                      style: AppType.bodyMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
