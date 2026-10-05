import 'package:flutter/material.dart';

import '../../../data/project_repository.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../panel.dart';
import 'dashboard_format.dart';

/// Where the grid stands, shown as context and never as a verdict.
///
/// Deliberately neutral in colour. The signal ramp is reserved for project
/// health, and tinting this strip would imply the outage is a health state of
/// the team. Outage hours are removed from available time before any score is
/// taken, so the copy says so out loud: the strip exists to show the team the
/// app has accounted for the power cut, not to grade it.
class GridStrip extends StatelessWidget {
  const GridStrip({super.key, required this.grid});

  final GridStatus grid;

  @override
  Widget build(BuildContext context) {
    final hasStage = grid.stage > 0;
    final start = grid.nextOutageStart;
    final end = grid.nextOutageEnd;
    final lost = grid.hoursLostThisWeek;

    return Panel(
      padding: const EdgeInsets.all(Tokens.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: Tokens.space1),
            child: Icon(Icons.bolt_outlined, size: 16, color: Tokens.slate),
          ),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasStage
                      ? 'Load-shedding · Stage ${grid.stage}'
                      : 'Grid stable',
                  style: AppType.bodyStrong,
                ),
                if (start != null && end != null) ...[
                  const SizedBox(height: Tokens.space1),
                  Text(
                    'Next outage ${clockTime(start)}–${clockTime(end)}',
                    style: AppType.data,
                  ),
                ],
                const SizedBox(height: Tokens.space1),
                Text(
                  lost > 0
                      ? '${hoursLabel(lost)} lost this week. Reported for '
                            'context: scores only measure the time your '
                            'squads had.'
                      : 'No outage hours lost this week.',
                  style: AppType.bodyMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
