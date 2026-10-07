import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/health_state.dart';
import '../models/project.dart';
import '../models/signal.dart';
import '../models/squad.dart';
import '../widgets/health_seam.dart';
import 'project_repository.dart';

/// Keeps the last good snapshot on the device.
///
/// This is the offline half of the thesis. A team lead checking project health
/// during a four-hour outage, on a phone with no signal, should still see
/// yesterday's numbers and be told they are yesterday's — rather than a spinner
/// or an error, which is what every tool the research criticises would show.
///
/// Stored as JSON in shared preferences. A snapshot is a few kilobytes and is
/// always read whole, so a full database would be machinery without a purpose.
class LocalCache {
  const LocalCache();

  static const _snapshotKey = 'cached_snapshot';
  static const _capturedAtKey = 'cached_captured_at';

  Future<void> save(HealthSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();

    final payload = {
      'projects': snapshot.projects.map(_projectToMap).toList(),
      'squads': snapshot.squads.map(_squadToMap).toList(),
      'signals': snapshot.signals.map(_signalToMap).toList(),
      'grid': {
        'stage': snapshot.grid.stage,
        'nextOutageStart': snapshot.grid.nextOutageStart?.toIso8601String(),
        'nextOutageEnd': snapshot.grid.nextOutageEnd?.toIso8601String(),
        'hoursLostThisWeek': snapshot.grid.hoursLostThisWeek,
      },
      'capturedAt': snapshot.capturedAt.toIso8601String(),
    };

    await prefs.setString(_snapshotKey, jsonEncode(payload));
    await prefs.setString(
      _capturedAtKey,
      snapshot.capturedAt.toIso8601String(),
    );
  }

  /// The last saved snapshot, or null if nothing has been cached.
  ///
  /// Always returned with `isLive: false`, so anything rendering it is obliged
  /// to say the data is not current.
  Future<HealthSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapshotKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      final grid = decoded['grid'] as Map<String, dynamic>? ?? const {};

      return HealthSnapshot(
        projects: (decoded['projects'] as List<dynamic>? ?? const [])
            .map((m) => _projectFromMap(m as Map<String, dynamic>))
            .toList(),
        squads: (decoded['squads'] as List<dynamic>? ?? const [])
            .map((m) => _squadFromMap(m as Map<String, dynamic>))
            .toList(),
        signals: (decoded['signals'] as List<dynamic>? ?? const [])
            .map((m) => _signalFromMap(m as Map<String, dynamic>))
            .toList(),
        grid: GridStatus(
          stage: (grid['stage'] as num?)?.toInt() ?? 0,
          nextOutageStart: DateTime.tryParse('${grid['nextOutageStart']}'),
          nextOutageEnd: DateTime.tryParse('${grid['nextOutageEnd']}'),
          hoursLostThisWeek:
              (grid['hoursLostThisWeek'] as num?)?.toDouble() ?? 0,
        ),
        capturedAt:
            DateTime.tryParse('${decoded['capturedAt']}') ?? DateTime.now(),
        isLive: false,
      );
    } catch (_) {
      // A cache that cannot be read is worse than no cache. Drop it rather
      // than crashing the app on launch.
      await clear();
      return null;
    }
  }

  Future<DateTime?> lastCapturedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_capturedAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snapshotKey);
    await prefs.remove(_capturedAtKey);
  }

  // --- Serialisation --------------------------------------------------------

  Map<String, dynamic> _projectToMap(Project p) => {
    'id': p.id,
    'name': p.name,
    'client': p.client,
    'squadId': p.squadId,
    'score': p.score,
    'openSignals': p.openSignals,
    'budgetBurn': p.budgetBurn,
    'scheduleDaysRemaining': p.scheduleDaysRemaining,
    'loadSheddingHoursLost': p.loadSheddingHoursLost,
    'scheduleTotalDays': p.scheduleTotalDays,
    'velocityRatio': p.velocityRatio,
    'factors': p.factors
        .map(
          (f) => {
            'name': f.name,
            'value': f.value,
            'weight': f.weight,
            'detail': f.detail,
          },
        )
        .toList(),
    'seam': p.seam
        .map(
          (s) => {
            'state': s.state.name,
            'periodLabel': s.periodLabel,
            'flagged': s.flagged,
          },
        )
        .toList(),
  };

  Project _projectFromMap(Map<String, dynamic> m) => Project(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    client: m['client'] as String? ?? '',
    squadId: m['squadId'] as String? ?? '',
    score: (m['score'] as num?)?.toDouble() ?? 0,
    openSignals: (m['openSignals'] as num?)?.toInt() ?? 0,
    budgetBurn: (m['budgetBurn'] as num?)?.toDouble() ?? 0,
    scheduleDaysRemaining: (m['scheduleDaysRemaining'] as num?)?.toInt() ?? 0,
    loadSheddingHoursLost:
        (m['loadSheddingHoursLost'] as num?)?.toDouble() ?? 0,
    scheduleTotalDays: (m['scheduleTotalDays'] as num?)?.toInt() ?? 0,
    velocityRatio: (m['velocityRatio'] as num?)?.toDouble() ?? 1,
    factors: (m['factors'] as List<dynamic>? ?? const [])
        .map((f) => f as Map<String, dynamic>)
        .map(
          (f) => HealthFactor(
            name: f['name'] as String? ?? '',
            value: (f['value'] as num?)?.toDouble() ?? 0,
            weight: (f['weight'] as num?)?.toDouble() ?? 0,
            detail: f['detail'] as String? ?? '',
          ),
        )
        .toList(),
    seam: (m['seam'] as List<dynamic>? ?? const [])
        .map((s) => s as Map<String, dynamic>)
        .map(
          (s) => SeamSegment(
            state: HealthState.fromName(s['state'] as String?),
            periodLabel: s['periodLabel'] as String? ?? '',
            flagged: s['flagged'] as bool? ?? false,
          ),
        )
        .toList(),
  );

  Map<String, dynamic> _squadToMap(Squad s) => {
    'id': s.id,
    'name': s.name,
    'headcount': s.headcount,
    'capacityUsed': s.capacityUsed,
    'activeProjectCount': s.activeProjectCount,
    'velocityTrend': s.velocityTrend,
  };

  Squad _squadFromMap(Map<String, dynamic> m) => Squad(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    headcount: (m['headcount'] as num?)?.toInt() ?? 0,
    capacityUsed: (m['capacityUsed'] as num?)?.toDouble() ?? 0,
    activeProjectCount: (m['activeProjectCount'] as num?)?.toInt() ?? 0,
    velocityTrend: (m['velocityTrend'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> _signalToMap(Signal s) => {
    'id': s.id,
    'title': s.title,
    'because': s.because,
    'severity': s.severity.name,
    'projectId': s.projectId,
    'raisedAt': s.raisedAt.toIso8601String(),
    'infrastructureRelated': s.infrastructureRelated,
  };

  Signal _signalFromMap(Map<String, dynamic> m) => Signal(
    id: m['id'] as String? ?? '',
    title: m['title'] as String? ?? '',
    because: m['because'] as String? ?? '',
    severity: HealthState.fromName(m['severity'] as String?),
    projectId: m['projectId'] as String? ?? '',
    raisedAt: DateTime.tryParse('${m['raisedAt']}') ?? DateTime.now(),
    infrastructureRelated: m['infrastructureRelated'] as bool? ?? false,
  );
}
