import 'dart:async';
import 'dart:math';

import '../models/health_state.dart';
import '../models/project.dart';
import '../models/signal.dart';
import '../models/squad.dart';
import '../widgets/health_seam.dart';
import 'project_repository.dart';

/// Stands in for passive ingestion until a real one exists.
///
/// It drifts the numbers on a timer so the live behaviour of the UI can be
/// seen and demonstrated. Nothing outside this file knows the data is fake.
class MockProjectRepository implements ProjectRepository {
  MockProjectRepository();

  final _random = Random(7); // seeded, so a demo looks the same twice
  final _controller = StreamController<HealthSnapshot>.broadcast();
  Timer? _timer;

  late List<Project> _projects = _seedProjects();
  late final List<Squad> _squads = _seedSquads();
  late final List<Signal> _signals = _seedSignals();
  final GridStatus _grid = _seedGrid();

  @override
  Stream<HealthSnapshot> watch() {
    _timer ??= Timer.periodic(const Duration(seconds: 4), (_) => _tick());
    scheduleMicrotask(_emit);
    return _controller.stream;
  }

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(
      HealthSnapshot(
        projects: _projects,
        squads: _squads,
        signals: _signals,
        grid: _grid,
        capturedAt: DateTime.now(),
        isLive: true,
      ),
    );
  }

  /// Nudges each score a little, so the dashboard visibly breathes.
  void _tick() {
    _projects = _projects.map((p) {
      final drift = (_random.nextDouble() - 0.48) * 3.5;
      final score = (p.score + drift).clamp(8.0, 98.0);
      return Project(
        id: p.id,
        name: p.name,
        client: p.client,
        squadId: p.squadId,
        score: score,
        factors: p.factors,
        seam: p.seam,
        openSignals: p.openSignals,
        budgetBurn: p.budgetBurn,
        scheduleDaysRemaining: p.scheduleDaysRemaining,
        loadSheddingHoursLost: p.loadSheddingHoursLost,
      );
    }).toList();
    _emit();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  // --- Seed data -----------------------------------------------------------

  static GridStatus _seedGrid() {
    final now = DateTime.now();
    return GridStatus(
      stage: 2,
      nextOutageStart: now.add(const Duration(hours: 3, minutes: 10)),
      nextOutageEnd: now.add(const Duration(hours: 5, minutes: 40)),
      hoursLostThisWeek: 11.5,
    );
  }

  List<SeamSegment> _seedSeam({
    required List<HealthState> states,
    required Set<int> flags,
  }) {
    final today = DateTime.now();
    return [
      for (var i = 0; i < states.length; i++)
        SeamSegment(
          state: states[i],
          periodLabel: _shortDate(
            today.subtract(Duration(days: states.length - 1 - i)),
          ),
          flagged: flags.contains(i),
        ),
    ];
  }

  static String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  /// A run of one state, for building readable histories.
  static List<HealthState> _run(HealthState s, int n) =>
      List.filled(n, s, growable: false);

  List<Project> _seedProjects() {
    return [
      Project(
        id: 'p1',
        name: 'Ledger rebuild',
        client: 'Thornhill Financial',
        squadId: 's1',
        score: 28,
        openSignals: 4,
        budgetBurn: 0.94,
        scheduleDaysRemaining: 11,
        loadSheddingHoursLost: 6.5,
        seam: _seedSeam(
          states: [
            ..._run(HealthState.onTrack, 9),
            ..._run(HealthState.watch, 6),
            ..._run(HealthState.atRisk, 8),
            ..._run(HealthState.critical, 7),
          ],
          flags: {15, 22, 26, 29},
        ),
        factors: const [
          HealthFactor(
            name: 'Budget burn',
            value: 18,
            weight: 0.25,
            detail: '94% of budget spent with 11 days of scope remaining',
          ),
          HealthFactor(
            name: 'Task velocity',
            value: 31,
            weight: 0.25,
            detail: 'Throughput down 38% against this squad’s own baseline',
          ),
          HealthFactor(
            name: 'Issue complexity ratio',
            value: 24,
            weight: 0.2,
            detail: 'Open issues skewing heavier as simpler work is cleared',
          ),
          HealthFactor(
            name: 'Commit volume',
            value: 42,
            weight: 0.15,
            detail: 'Steady, but concentrated in one area of the codebase',
          ),
          HealthFactor(
            name: 'Idle-time ratio',
            value: 35,
            weight: 0.15,
            detail: '6.5 hours lost to outages, already excluded from this score',
          ),
        ],
      ),
      Project(
        id: 'p2',
        name: 'Fleet tracker v2',
        client: 'Marula Logistics',
        squadId: 's2',
        score: 47,
        openSignals: 2,
        budgetBurn: 0.61,
        scheduleDaysRemaining: 34,
        loadSheddingHoursLost: 3.0,
        seam: _seedSeam(
          states: [
            ..._run(HealthState.onTrack, 12),
            ..._run(HealthState.watch, 9),
            ..._run(HealthState.atRisk, 6),
            ..._run(HealthState.watch, 3),
          ],
          flags: {19, 24},
        ),
        factors: const [
          HealthFactor(
            name: 'Budget burn',
            value: 62,
            weight: 0.25,
            detail: '61% spent against 58% of the schedule elapsed',
          ),
          HealthFactor(
            name: 'Task velocity',
            value: 44,
            weight: 0.25,
            detail: 'Slowed for three sprints running',
          ),
          HealthFactor(
            name: 'Issue complexity ratio',
            value: 51,
            weight: 0.2,
            detail: 'Backlog weight stable',
          ),
          HealthFactor(
            name: 'Commit volume',
            value: 38,
            weight: 0.15,
            detail: 'Down 22%, tracking the outage window',
          ),
          HealthFactor(
            name: 'Idle-time ratio',
            value: 40,
            weight: 0.15,
            detail: '3 hours lost to outages this week',
          ),
        ],
      ),
      Project(
        id: 'p3',
        name: 'Clinic booking portal',
        client: 'Sibanye Health',
        squadId: 's1',
        score: 64,
        openSignals: 1,
        budgetBurn: 0.42,
        scheduleDaysRemaining: 52,
        loadSheddingHoursLost: 2.0,
        seam: _seedSeam(
          states: [
            ..._run(HealthState.watch, 7),
            ..._run(HealthState.onTrack, 14),
            ..._run(HealthState.watch, 9),
          ],
          flags: {8},
        ),
        factors: const [
          HealthFactor(
            name: 'Budget burn',
            value: 71,
            weight: 0.25,
            detail: 'Tracking slightly under plan',
          ),
          HealthFactor(
            name: 'Task velocity',
            value: 58,
            weight: 0.25,
            detail: 'Recovered after last sprint’s dip',
          ),
          HealthFactor(
            name: 'Issue complexity ratio',
            value: 66,
            weight: 0.2,
            detail: 'Healthy mix of work sizes',
          ),
          HealthFactor(
            name: 'Commit volume',
            value: 69,
            weight: 0.15,
            detail: 'Consistent across the squad',
          ),
          HealthFactor(
            name: 'Idle-time ratio',
            value: 55,
            weight: 0.15,
            detail: '2 hours lost to outages this week',
          ),
        ],
      ),
      Project(
        id: 'p4',
        name: 'POS integration',
        client: 'Kloof Retail Group',
        squadId: 's3',
        score: 82,
        openSignals: 0,
        budgetBurn: 0.35,
        scheduleDaysRemaining: 68,
        loadSheddingHoursLost: 1.5,
        seam: _seedSeam(
          states: [
            ..._run(HealthState.onTrack, 18),
            ..._run(HealthState.watch, 4),
            ..._run(HealthState.onTrack, 8),
          ],
          flags: {},
        ),
        factors: const [
          HealthFactor(
            name: 'Budget burn',
            value: 88,
            weight: 0.25,
            detail: '35% spent against 32% of the schedule elapsed',
          ),
          HealthFactor(
            name: 'Task velocity',
            value: 79,
            weight: 0.25,
            detail: 'Steady against baseline',
          ),
          HealthFactor(
            name: 'Issue complexity ratio',
            value: 84,
            weight: 0.2,
            detail: 'Backlog clearing evenly',
          ),
          HealthFactor(
            name: 'Commit volume',
            value: 77,
            weight: 0.15,
            detail: 'Well distributed across the squad',
          ),
          HealthFactor(
            name: 'Idle-time ratio',
            value: 81,
            weight: 0.15,
            detail: 'Backup power holding through outages',
          ),
        ],
      ),
    ];
  }

  List<Squad> _seedSquads() => const [
        Squad(
          id: 's1',
          name: 'Platform squad',
          headcount: 4,
          capacityUsed: 1.28,
          activeProjectCount: 2,
          velocityTrend: -0.31,
        ),
        Squad(
          id: 's2',
          name: 'Mobile squad',
          headcount: 3,
          capacityUsed: 1.02,
          activeProjectCount: 1,
          velocityTrend: -0.12,
        ),
        Squad(
          id: 's3',
          name: 'Integrations squad',
          headcount: 3,
          capacityUsed: 0.78,
          activeProjectCount: 1,
          velocityTrend: 0.04,
        ),
      ];

  List<Signal> _seedSignals() {
    final now = DateTime.now();
    return [
      Signal(
        id: 'sig1',
        title: 'Ledger rebuild will exhaust its budget before scope closes',
        because:
            'Burn reached 94% with 11 days of work left. At the current rate '
            'the budget runs out around 8 days early.',
        severity: HealthState.critical,
        projectId: 'p1',
        raisedAt: now.subtract(const Duration(hours: 2)),
      ),
      Signal(
        id: 'sig2',
        title: 'Platform squad has been over capacity for nine days',
        because:
            'Committed work sits at 128% of available capacity across two '
            'projects. Sustained over-allocation precedes schedule slip.',
        severity: HealthState.atRisk,
        projectId: 'p1',
        raisedAt: now.subtract(const Duration(hours: 6)),
      ),
      Signal(
        id: 'sig3',
        title: 'Stage 2 outage will remove 2.5 hours from tomorrow',
        because:
            'Scheduled outage overlaps the Mobile squad’s working window. '
            'Capacity forecasts have been adjusted; no project has been scored '
            'down for it.',
        severity: HealthState.watch,
        projectId: 'p2',
        raisedAt: now.subtract(const Duration(hours: 1)),
        infrastructureRelated: true,
      ),
      Signal(
        id: 'sig4',
        title: 'Fleet tracker velocity down three sprints running',
        because:
            'Throughput fell 12%, 18% and 9% against the squad baseline. The '
            'decline is steeper than outage hours alone explain.',
        severity: HealthState.atRisk,
        projectId: 'p2',
        raisedAt: now.subtract(const Duration(days: 1)),
      ),
      Signal(
        id: 'sig5',
        title: 'Clinic portal backlog weight rising',
        because:
            'Remaining issues are trending more complex as simpler work is '
            'cleared. Watch the next two sprints.',
        severity: HealthState.watch,
        projectId: 'p3',
        raisedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
