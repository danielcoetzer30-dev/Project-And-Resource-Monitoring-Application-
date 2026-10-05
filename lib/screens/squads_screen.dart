import 'package:flutter/material.dart';

import '../data/project_repository.dart';
import '../models/squad.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/panel.dart';
import '../widgets/status_pill.dart';

/// Capacity at squad level, deliberately never at person level.
///
/// The whole screen is built so that "the Platform squad is over capacity" is
/// answerable and "who on the Platform squad is slowest" is not.
class SquadsScreen extends StatelessWidget {
  const SquadsScreen({super.key, required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        Tokens.space2,
        Tokens.space4,
        Tokens.space7,
      ),
      children: [
        Panel(
          title: 'How this is measured',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: Tokens.slate),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Text(
                  'Capacity is aggregated per squad. Individual activity is '
                  'never stored, scored or shown — not to you, and not to '
                  'management.',
                  style: AppType.bodyMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space4),
        for (final squad in snapshot.squads) ...[
          _SquadCard(squad: squad),
          const SizedBox(height: Tokens.space3),
        ],
      ],
    );
  }
}

class _SquadCard extends StatelessWidget {
  const _SquadCard({required this.squad});

  final Squad squad;

  @override
  Widget build(BuildContext context) {
    final over = squad.capacityUsed > 1;
    final trendDown = squad.velocityTrend < 0;

    return Container(
      padding: const EdgeInsets.all(Tokens.space4),
      decoration: BoxDecoration(
        color: Tokens.seam,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.rule, width: Tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(squad.name, style: AppType.heading),
                    const SizedBox(height: Tokens.space1),
                    Text(
                      '${squad.headcount} people  ·  '
                      '${squad.activeProjectCount} active '
                      '${squad.activeProjectCount == 1 ? 'project' : 'projects'}',
                      style: AppType.bodyMuted,
                    ),
                  ],
                ),
              ),
              StatusPill(state: squad.state),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          _CapacityBar(squad: squad),
          const SizedBox(height: Tokens.space3),
          Row(
            children: [
              Text(
                squad.capacityLabel,
                style: AppType.metricSmall.copyWith(color: squad.state.color),
              ),
              const SizedBox(width: Tokens.space2),
              Expanded(
                child: Text(
                  over ? 'of capacity committed' : 'of capacity committed',
                  style: AppType.bodyMuted,
                ),
              ),
              Icon(
                trendDown ? Icons.south_east : Icons.north_east,
                size: 14,
                color: trendDown ? Tokens.ember : Tokens.jade,
              ),
              const SizedBox(width: Tokens.space1),
              Text(
                '${(squad.velocityTrend * 100).round().abs()}%',
                style: AppType.dataStrong,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapacityBar extends StatelessWidget {
  const _CapacityBar({required this.squad});

  final Squad squad;

  @override
  Widget build(BuildContext context) {
    // The bar is scaled so 100% sits at a fixed marker rather than at the far
    // edge — over-allocation has to be visible as overflow, not just as a
    // full bar.
    const fullMark = 0.72;
    final fill = (squad.capacityUsed * fullMark).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 10,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Tokens.shaft,
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  border: Border.all(color: Tokens.rule),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fill,
                child: Container(
                  decoration: BoxDecoration(
                    color: squad.state.color,
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
                  ),
                ),
              ),
              Positioned(
                left: width * fullMark,
                top: -2,
                bottom: -2,
                child: Container(width: 1.5, color: Tokens.chalk),
              ),
            ],
          ),
        );
      },
    );
  }
}
