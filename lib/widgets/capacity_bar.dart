import 'package:flutter/material.dart';

import '../models/health_state.dart';
import '../theme/tokens.dart';

/// Squad capacity, with 100% marked rather than implied.
///
/// The full mark sits at roughly three-quarters of the width instead of at the
/// end, so over-allocation renders as visible overflow past a line. A bar that
/// simply fills tells you a squad is busy; this one tells you a squad is
/// committed beyond what it has, which is the leading indicator that matters.
///
/// Extracted from the squads screen so the project detail screen renders it
/// identically.
class CapacityBar extends StatelessWidget {
  const CapacityBar({
    super.key,
    required this.capacityUsed,
    required this.state,
    this.height = 10,
  });

  /// Fraction of capacity committed. Above 1 is over-allocation.
  final double capacityUsed;

  final HealthState state;
  final double height;

  /// Where 100% sits along the bar.
  static const _fullMark = 0.72;

  @override
  Widget build(BuildContext context) {
    final fill = (capacityUsed * _fullMark).clamp(0.0, 1.0);

    return Semantics(
      label:
          '${(capacityUsed * 100).round()} percent of capacity committed, '
          '${state.label}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: height,
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
                      color: state.color,
                      borderRadius: BorderRadius.circular(Tokens.radiusSm),
                    ),
                  ),
                ),
                Positioned(
                  left: constraints.maxWidth * _fullMark,
                  top: -2,
                  bottom: -2,
                  child: Container(width: 1.5, color: Tokens.chalk),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
