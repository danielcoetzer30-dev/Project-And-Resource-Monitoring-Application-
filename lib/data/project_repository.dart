import '../models/health_state.dart';
import '../models/project.dart';
import '../models/signal.dart';
import '../models/squad.dart';

/// Current grid state. Load-shedding is modelled as a first-class input rather
/// than an annotation, because separating "the team is slipping" from "the
/// power was out for four hours" is the thing existing tools cannot do.
class GridStatus {
  const GridStatus({
    required this.stage,
    required this.nextOutageStart,
    required this.nextOutageEnd,
    required this.hoursLostThisWeek,
  });

  /// Eskom load-shedding stage, 0 when the grid is up.
  final int stage;
  final DateTime? nextOutageStart;
  final DateTime? nextOutageEnd;
  final double hoursLostThisWeek;

  bool get isShedding => stage > 0;
}

/// Everything the UI renders, as one consistent snapshot.
class HealthSnapshot {
  const HealthSnapshot({
    required this.projects,
    required this.squads,
    required this.signals,
    required this.grid,
    required this.capturedAt,
    required this.isLive,
  });

  final List<Project> projects;
  final List<Squad> squads;
  final List<Signal> signals;
  final GridStatus grid;

  /// When this data was actually captured — not when it was displayed.
  /// Connectivity is unreliable by assumption, so the UI always says how stale
  /// what you are looking at is.
  final DateTime capturedAt;

  /// False when showing cached data because ingestion is unreachable.
  final bool isLive;

  List<Project> get worstFirst {
    final sorted = [...projects];
    sorted.sort((a, b) {
      final bySeverity = b.state.severity.compareTo(a.state.severity);
      return bySeverity != 0 ? bySeverity : a.score.compareTo(b.score);
    });
    return sorted;
  }

  int countIn(HealthState state) =>
      projects.where((p) => p.state == state).length;
}

/// The UI talks only to this.
///
/// Data arrives passively — read from version control and issue trackers in
/// the background — so there is deliberately no method here for a person to
/// type in a status. Swapping the mock for a real ingestion service means
/// writing one new implementation, not touching any screen.
abstract interface class ProjectRepository {
  Stream<HealthSnapshot> watch();
  void dispose();
}
