import 'health_state.dart';

/// A team, never a person.
///
/// The research protocol this app implements commits to aggregation at squad
/// level and rules out individual analytics: the risk being mitigated is that
/// health data becomes a performance-management instrument. There is
/// deliberately no member-level metric anywhere in this model — only a
/// headcount, so capacity can be reasoned about without exposing anyone.
class Squad {
  const Squad({
    required this.id,
    required this.name,
    required this.headcount,
    required this.capacityUsed,
    required this.activeProjectCount,
    required this.velocityTrend,
  });

  final String id;
  final String name;

  /// How many people are in the squad. Not who.
  final int headcount;

  /// Fraction of available capacity committed, 0–1. Above 1 is
  /// over-allocation, a leading indicator of schedule slip.
  final double capacityUsed;

  final int activeProjectCount;

  /// Change in throughput against the squad's own recent baseline, as a
  /// fraction. Negative means slowing.
  final double velocityTrend;

  HealthState get state {
    if (capacityUsed > 1.25) return HealthState.critical;
    if (capacityUsed > 1.05) return HealthState.atRisk;
    if (capacityUsed > 0.95 || velocityTrend < -0.2) return HealthState.watch;
    return HealthState.onTrack;
  }

  String get capacityLabel => '${(capacityUsed * 100).round()}%';
}
