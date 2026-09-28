import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The four states everything in the app resolves to.
///
/// Each state carries a colour, an icon and a word. Presentation code should
/// use all three: colour alone is not an accessible signal, and this app is
/// read at a glance by people deciding whether to act.
enum HealthState {
  onTrack(
    label: 'On track',
    color: Tokens.jade,
    icon: Icons.check_circle_outline,
    severity: 0,
  ),
  watch(
    label: 'Watch',
    color: Tokens.brass,
    icon: Icons.trending_down,
    severity: 1,
  ),
  atRisk(
    label: 'At risk',
    color: Tokens.ember,
    icon: Icons.warning_amber_outlined,
    severity: 2,
  ),
  critical(
    label: 'Critical',
    color: Tokens.flare,
    icon: Icons.error_outline,
    severity: 3,
  );

  const HealthState({
    required this.label,
    required this.color,
    required this.icon,
    required this.severity,
  });

  final String label;
  final Color color;
  final IconData icon;

  /// Higher is worse. Used for sorting worst-first, which is the order that
  /// matters in an early warning system.
  final int severity;

  /// Maps a 0–100 health score onto a state.
  ///
  /// Thresholds are a starting point and will move once the interview data
  /// says where the real boundaries sit.
  static HealthState fromScore(double score) {
    if (score >= 75) return HealthState.onTrack;
    if (score >= 55) return HealthState.watch;
    if (score >= 35) return HealthState.atRisk;
    return HealthState.critical;
  }

  /// Parses a stored state name back into a state.
  ///
  /// Falls back to onTrack rather than throwing: a malformed document should
  /// not take down the whole dashboard.
  static HealthState fromName(String? name) {
    return HealthState.values.firstWhere(
      (state) => state.name == name,
      orElse: () => HealthState.onTrack,
    );
  }
}
