import 'health_state.dart';

/// An early warning. Named "signal" rather than "alert" on purpose: the tool
/// is diagnostic and supportive, and the vocabulary should not sound punitive
/// to the team being measured.
class Signal {
  const Signal({
    required this.id,
    required this.title,
    required this.because,
    required this.severity,
    required this.projectId,
    required this.raisedAt,
    this.infrastructureRelated = false,
  });

  final String id;

  /// What is happening, in the team's own terms.
  final String title;

  /// Why it fired. A warning without its reasoning is not actionable, and an
  /// unexplained score is exactly what makes monitoring feel like surveillance.
  final String because;

  final HealthState severity;
  final String projectId;
  final DateTime raisedAt;

  /// Attributable to grid or connectivity failure rather than to the team.
  /// Kept distinct so infrastructure problems are never read as underdelivery.
  final bool infrastructureRelated;
}
