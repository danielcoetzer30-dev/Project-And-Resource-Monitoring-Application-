import 'package:flutter/material.dart';

import '../../../models/health_state.dart';
import '../../../models/project.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../status_pill.dart';
import 'dashboard_format.dart';

/// How many projects sit in each health state, worst first.
///
/// Each tile is also the filter for that state, so the count and the control
/// are the same object rather than two things to keep in step. Every tile
/// renders through [StatusPill], so a state is never shown by colour alone.
class SummaryStrip extends StatelessWidget {
  const SummaryStrip({
    super.key,
    required this.projects,
    required this.selected,
    required this.onToggle,
  });

  final List<Project> projects;

  /// States currently filtering the list. Empty means no filter.
  final Set<HealthState> selected;

  final ValueChanged<HealthState> onToggle;

  @override
  Widget build(BuildContext context) {
    final order = HealthState.values.reversed.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Four across when there is room, two by two on a phone. A pill with
        // its word does not fit four-up at 360px.
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        const gap = Tokens.space2;
        final width = ((constraints.maxWidth - gap * (columns - 1)) / columns)
            .floorToDouble();

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final state in order)
              SizedBox(
                width: width,
                child: _SummaryTile(
                  state: state,
                  count: projects.where((p) => p.state == state).length,
                  isSelected: selected.contains(state),
                  onTap: () => onToggle(state),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.state,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final HealthState state;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      label:
          '${plural(count, 'project')} ${state.label}. '
          '${isSelected ? 'Remove' : 'Apply'} this filter.',
      child: Material(
        color: Tokens.seam,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          // Beacon marks "selected" because selection is an interactive
          // affordance, not a health reading.
          side: BorderSide(
            color: isSelected ? Tokens.beacon : Tokens.rule,
            width: Tokens.hairline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check, size: 16, color: Tokens.beacon),
                      const SizedBox(width: Tokens.space1),
                    ],
                    Text('$count', style: AppType.metricSmall),
                  ],
                ),
                StatusPill(state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
