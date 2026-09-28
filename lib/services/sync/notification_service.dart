import 'dart:async';

import '../../models/health_state.dart';
import '../../models/project.dart';

/// A health change worth telling someone about.
class HealthAlert {
  const HealthAlert({
    required this.projectId,
    required this.projectName,
    required this.from,
    required this.to,
    required this.raisedAt,
  });

  final String projectId;
  final String projectName;
  final HealthState from;
  final HealthState to;
  final DateTime raisedAt;

  bool get isWorsening => to.severity > from.severity;

  String get title => isWorsening
      ? '$projectName moved to ${to.label}'
      : '$projectName recovered to ${to.label}';
}

/// Watches for projects crossing into a worse state and raises an alert once.
///
/// Fires on the *transition*, not on the state. A project sitting at Critical
/// for a fortnight should generate one alert, not one every polling cycle —
/// an early warning system that cries wolf daily gets muted, and a muted
/// warning system is worse than none.
///
/// Recovery is announced too. A team that has pulled a project back deserves
/// to hear it, and it keeps the tool from reading as purely punitive.
class NotificationService {
  NotificationService({this.alertFrom = HealthState.atRisk});

  /// Only states at or above this severity raise an alert. Watch is a
  /// dashboard colour, not something worth a phone buzzing.
  final HealthState alertFrom;

  final _alerts = StreamController<HealthAlert>.broadcast();
  final _lastKnown = <String, HealthState>{};

  Stream<HealthAlert> get alerts => _alerts.stream;

  /// Call with each new snapshot's projects.
  void evaluate(List<Project> projects) {
    final now = DateTime.now();

    for (final project in projects) {
      final previous = _lastKnown[project.id];
      final current = project.state;

      _lastKnown[project.id] = current;

      // First time seeing this project: record its state but stay quiet.
      // Otherwise opening the app would alert on everything at once.
      if (previous == null) continue;
      if (previous == current) continue;

      final worsened = current.severity > previous.severity;
      final crossedThreshold = worsened
          ? current.severity >= alertFrom.severity
          : previous.severity >= alertFrom.severity;

      if (!crossedThreshold) continue;

      if (!_alerts.isClosed) {
        _alerts.add(
          HealthAlert(
            projectId: project.id,
            projectName: project.name,
            from: previous,
            to: current,
            raisedAt: now,
          ),
        );
      }
    }
  }

  /// Forgets recorded states, so the next evaluate starts fresh. Used on sign
  /// out, so one person's alerts never follow another into the app.
  void reset() => _lastKnown.clear();

  void dispose() => _alerts.close();
}
