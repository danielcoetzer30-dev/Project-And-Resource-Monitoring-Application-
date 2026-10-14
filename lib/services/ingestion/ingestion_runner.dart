import '../../core/constants/app_constants.dart';
import '../../core/errors/failure.dart';
import '../../models/health_state.dart';
import '../../models/ingestion_source.dart';
import '../../models/outage_window.dart';
import '../../models/project_metrics.dart';
import '../../models/project_plan.dart';
import '../../models/scoring_weights.dart';
import '../../models/signal.dart';
import '../../models/squad_activity.dart';
import '../health_scoring/health_score_engine.dart';
import '../signal_engine.dart';
import 'firestore_rest.dart';
import 'ingestion_service.dart';
import 'metrics_assembler.dart';

/// What one scheduled run did, for the job log.
class RunReport {
  const RunReport({
    required this.projectsScored,
    required this.signalsRaised,
    required this.suppressedSquads,
    required this.failures,
    required this.skipped,
  });

  final int projectsScored;
  final int signalsRaised;

  /// Squads dropped for having too few contributors to report anonymously.
  final List<String> suppressedSquads;

  /// Sources that could not be read. A run continues past these.
  final Map<String, Failure> failures;

  /// Projects that could not be scored, and why.
  final Map<String, String> skipped;

  /// Lines for the Action log. Written plainly so a teammate reading a failed
  /// run understands it without opening the code.
  List<String> get summary => [
    'Scored $projectsScored project(s), raised $signalsRaised signal(s).',
    if (suppressedSquads.isNotEmpty)
      'Suppressed ${suppressedSquads.length} squad(s) with too few '
          'contributors to report anonymously: '
          '${suppressedSquads.join(', ')}.',
    for (final entry in skipped.entries) 'Skipped ${entry.key}: ${entry.value}',
    for (final entry in failures.entries)
      'Source ${entry.key} failed: ${entry.value.message}',
  ];
}

/// One scheduled pass: read the sources, aggregate, score, write.
///
/// This is the half of ingestion that had no home until now. [IngestionService]
/// already turned raw events into anonymous squad totals; this takes those
/// totals, joins them to the team's plan and the squad's own history, scores
/// them with the same engine the app was built around, and writes the result
/// where the app reads it.
///
/// It writes as a service account, which is not subject to `firestore.rules`.
/// That is deliberate: `projects`, `squads` and `signals` stay unwritable by
/// every client, and this is the only identity that can change them.
class IngestionRunner {
  const IngestionRunner({
    required this.firestore,
    required this.service,
    required this.engine,
    required this.orgId,
    this.assembler = const MetricsAssembler(),
    this.signalEngine = const SignalEngine(),
  });

  final FirestoreStore firestore;
  final IngestionService service;
  final HealthScoreEngine engine;
  final MetricsAssembler assembler;
  final SignalEngine signalEngine;
  final String orgId;

  String get _org => 'organisations/$orgId';

  /// Working state only ingestion reads or writes: the past windows a baseline
  /// is drawn from. No client has a rule granting access to it.
  static const activityHistoryCollection = 'activityHistory';

  Future<RunReport> run({
    required Map<String, String> tokensBySourceId,
    required DateTime now,
    Duration window = const Duration(hours: 6),
  }) async {
    final windowStart = now.subtract(window);

    final sources = await _readSources();
    final weights = await _readWeights();

    final result = await service.run(
      sources: sources,
      tokensBySourceId: tokensBySourceId,
      windowStart: windowStart,
      windowEnd: now,
    );

    final activityBySquad = {
      for (final activity in result.activity) activity.squadId: activity,
    };

    final projects = await firestore.list('$_org/projects');
    final plans = await firestore.list('$_org/projectPlans');
    final outages = await _readOutages();

    var scored = 0;
    var raised = 0;
    final skipped = <String, String>{};

    // Two projects can share a squad, and the history behind them is the
    // same. Read once: Firestore reads are the metered thing on the free
    // plan, and this runs four times a day forever.
    final historyCache = <String, List<SquadActivity>>{};

    Future<List<SquadActivity>> historyFor(String squadId) async =>
        historyCache[squadId] ??= await _readHistory(squadId);

    for (final entry in projects.entries) {
      final projectId = entry.key;
      final document = entry.value;

      final squadId = document['squadId'] as String? ?? '';
      final activity = activityBySquad[squadId];

      if (activity == null) {
        // No activity reaching here is not the same as no activity happening:
        // the squad may have been suppressed for anonymity, or its source may
        // have failed. Either way, last run's score stands rather than being
        // overwritten with a zero that reads as collapse.
        skipped[projectId] = result.suppressedSquads.contains(squadId)
            ? 'squad suppressed for anonymity'
            : 'no activity reported for squad $squadId';
        continue;
      }

      final plan = _planFrom(projectId, plans[projectId]);
      final history = await historyFor(squadId);

      final metrics = assembler.assemble(
        projectId: projectId,
        activity: activity,
        plan: plan,
        history: history,
        outages: outages,
        now: now,
      );

      final assessment = engine.score(metrics: metrics, weights: weights);

      final projectName = document['name'] as String? ?? projectId;
      final signals = signalEngine.evaluate(
        assessment: assessment,
        metrics: metrics,
        projectName: projectName,
      );

      await _writeProject(
        projectId: projectId,
        existing: document,
        assessment: assessment,
        metrics: metrics,
        plan: plan,
        openSignals: signals.length,
        // Reported over the week, not the poll window: the Week tab adds
        // these up and calls the total "hours lost this week", and a
        // six-hour slice under that heading would be wrong.
        outageHoursThisWeek: assembler.outageHoursIn(
          outages: outages,
          squadId: squadId,
          windowStart: now.subtract(const Duration(days: 7)),
          windowEnd: now,
        ),
        now: now,
      );

      await _replaceSignalsFor(projectId: projectId, signals: signals);

      scored++;
      raised += signals.length;
    }

    // Before the history is appended, so a squad's baseline is still the
    // windows before this one rather than including it.
    await _writeSquads(
      activityBySquad: activityBySquad,
      projects: projects,
      plans: plans,
      historyFor: historyFor,
      now: now,
    );

    for (final activity in result.activity) {
      await _appendHistory(activity);
    }

    return RunReport(
      projectsScored: scored,
      signalsRaised: raised,
      suppressedSquads: result.suppressedSquads,
      failures: result.failures,
      skipped: skipped,
    );
  }

  // --- Reads ----------------------------------------------------------------

  Future<List<IngestionSource>> _readSources() async {
    final documents = await firestore.list('$_org/sources');

    return [
      for (final entry in documents.entries)
        IngestionSource(
          id: entry.key,
          type: SourceType.values.firstWhere(
            (type) => type.name == entry.value['type'],
            orElse: () => SourceType.github,
          ),
          label: entry.value['label'] as String? ?? entry.key,
          remoteId: entry.value['remoteId'] as String? ?? '',
          orgId: orgId,
          isEnabled: entry.value['isEnabled'] as bool? ?? true,
        ),
    ];
  }

  /// The team's own weights, so a scheduled run scores projects the same way
  /// the settings screen says they are scored. Defaults when never saved.
  Future<ScoringWeights> _readWeights() async {
    final document = await firestore.get(
      '$_org/${AppConstants.settingsCollection}/'
      '${AppConstants.scoringWeightsDoc}',
    );

    if (document == null) return const ScoringWeights.defaults();
    return ScoringWeights.fromMap(document);
  }

  Future<List<OutageWindow>> _readOutages() async {
    final documents = await firestore.list('$_org/outages');

    return [
      for (final entry in documents.entries)
        if (entry.value['start'] is DateTime && entry.value['end'] is DateTime)
          OutageWindow(
            id: entry.key,
            stage: (entry.value['stage'] as num?)?.toInt() ?? 0,
            start: entry.value['start'] as DateTime,
            end: entry.value['end'] as DateTime,
            affectedSquadIds: [
              for (final id in entry.value['affectedSquadIds'] as List? ?? [])
                id.toString(),
            ],
          ),
    ];
  }

  ProjectPlan _planFrom(String projectId, Map<String, dynamic>? document) {
    if (document == null) return ProjectPlan(projectId: projectId);

    return ProjectPlan(
      projectId: projectId,
      budgetTotal: (document['budgetTotal'] as num?)?.toDouble() ?? 0,
      budgetSpent: (document['budgetSpent'] as num?)?.toDouble() ?? 0,
      startDate: document['startDate'] as DateTime?,
      endDate: document['endDate'] as DateTime?,
      weeklyHours: (document['weeklyHours'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<SquadActivity>> _readHistory(String squadId) async {
    final document = await firestore.get(
      '$_org/$activityHistoryCollection/$squadId',
    );

    final windows = document?['windows'] as List? ?? const [];

    return [
      for (final entry in windows)
        if (entry is Map<String, dynamic>)
          SquadActivity(
            squadId: squadId,
            windowStart: entry['windowStart'] as DateTime? ?? DateTime(2000),
            windowEnd: entry['windowEnd'] as DateTime? ?? DateTime(2000),
            commitCount: (entry['commitCount'] as num?)?.toInt() ?? 0,
            tasksCompleted: (entry['tasksCompleted'] as num?)?.toInt() ?? 0,
            tasksOpened: (entry['tasksOpened'] as num?)?.toInt() ?? 0,
            closedIssueWeight:
                (entry['closedIssueWeight'] as num?)?.toDouble() ?? 0,
            openIssueWeight:
                (entry['openIssueWeight'] as num?)?.toDouble() ?? 0,
            contributorCount: (entry['contributorCount'] as num?)?.toInt() ?? 0,
            activePersonHours:
                (entry['activePersonHours'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  // --- Writes ---------------------------------------------------------------

  Future<void> _writeProject({
    required String projectId,
    required Map<String, dynamic> existing,
    required HealthAssessment assessment,
    required ProjectMetrics metrics,
    required ProjectPlan plan,
    required int openSignals,
    required double outageHoursThisWeek,
    required DateTime now,
  }) async {
    final seam = _appendToSeam(
      existing: existing['seam'] as List? ?? const [],
      state: assessment.state,
      flagged: openSignals > 0,
      now: now,
    );

    final fields = <String, dynamic>{
      'score': assessment.score,
      'factors': [
        for (final factor in assessment.factors)
          {
            'name': factor.name,
            'value': factor.value,
            'weight': factor.weight,
            'detail': factor.detail,
          },
      ],
      'seam': seam,
      'openSignals': openSignals,
      'loadSheddingHoursLost': outageHoursThisWeek,
      'updatedAt': now,
    };

    // The forecaster divides schedule remaining by this to project a
    // completion date. Leaving it stale would pair a fresh burn rate with
    // last month's velocity and produce a confidently wrong date — worse
    // than no forecast, which the forecaster is otherwise careful to give.
    if (metrics.tasksCompletedBaseline > 0) {
      fields['velocityRatio'] =
          metrics.tasksCompletedInWindow / metrics.tasksCompletedBaseline;
    }

    // Only written when the plan actually says something. Writing a zero burn
    // for a project nobody filled in would read as "spent nothing", which is
    // a claim rather than an absence.
    if (plan.budgetTotal > 0) {
      fields['budgetBurn'] = plan.budgetSpent / plan.budgetTotal;
    }

    final daysRemaining = plan.scheduleDaysRemainingAt(now);
    if (daysRemaining != null) {
      fields['scheduleDaysRemaining'] = daysRemaining;
    }

    // A merge, not a replace: name, client and squadId belong to whoever set
    // the project up, and a scoring run has no business rewriting them.
    await firestore.write(
      '$_org/projects/$projectId',
      fields,
      mergeFields: fields.keys.toList(),
    );
  }

  /// Updates what the Squads tab shows.
  ///
  /// Only ever a merge, and only the three fields ingestion can actually
  /// measure. `name` and `headcount` are stated by the team — a headcount is
  /// not something a commit log knows, and overwriting it with a guess would
  /// be worse than leaving it alone.
  ///
  /// Nothing written here is per-person. `velocityTrend` is a squad total
  /// against that squad's own past totals, and `capacityUsed` divides by a
  /// headcount rather than naming anybody.
  Future<void> _writeSquads({
    required Map<String, SquadActivity> activityBySquad,
    required Map<String, Map<String, dynamic>> projects,
    required Map<String, Map<String, dynamic>> plans,
    required Future<List<SquadActivity>> Function(String squadId) historyFor,
    required DateTime now,
  }) async {
    final squads = await firestore.list('$_org/squads');

    for (final entry in activityBySquad.entries) {
      final squadId = entry.key;
      final activity = entry.value;

      final squad = squads[squadId];
      if (squad == null) continue;

      final history = await historyFor(squadId);
      final baseline = assembler.baselineOf(
        history.map((window) => window.tasksCompleted.toDouble()),
        fallback: activity.tasksCompleted.toDouble(),
      );

      final squadProjects = [
        for (final project in projects.entries)
          if (project.value['squadId'] == squadId) project.key,
      ];

      final fields = <String, dynamic>{
        'activeProjectCount': squadProjects.length,
        'updatedAt': now,
      };

      // A ratio of 1 is no change, so the trend is the distance from it.
      // Without a baseline there is no trend to report, and zero would be a
      // claim of "steady" rather than an absence.
      if (baseline > 0) {
        fields['velocityTrend'] = (activity.tasksCompleted / baseline) - 1;
      }

      final committed = squadProjects
          .map((id) => _planFrom(id, plans[id]).weeklyHours)
          .fold<double>(0, (sum, hours) => sum + hours);

      final headcount = (squad['headcount'] as num?)?.toInt() ?? 0;

      // Hours committed across the squad's projects against the hours the
      // squad has. Written only when both are known: a capacity of zero
      // would render as an idle team rather than as an unanswered question.
      if (committed > 0 && headcount > 0) {
        fields['capacityUsed'] = committed / (headcount * _hoursPerWeek);
      }

      await firestore.write(
        '$_org/squads/$squadId',
        fields,
        mergeFields: fields.keys.toList(),
      );
    }
  }

  /// A full working week per person, for turning a headcount into capacity.
  static const _hoursPerWeek = 40.0;

  /// Adds today's state to the project's history strip.
  ///
  /// One segment per day, replacing today's if the job has already run. A
  /// segment per run would fill the strip with six-hour slivers and make a
  /// 30-day trend unreadable.
  List<Map<String, dynamic>> _appendToSeam({
    required List<dynamic> existing,
    required HealthState state,
    required bool flagged,
    required DateTime now,
  }) {
    final label = _dayLabel(now);

    final segments = <Map<String, dynamic>>[
      for (final entry in existing)
        if (entry is Map<String, dynamic>) entry,
    ];

    final today = <String, dynamic>{
      'state': state.name,
      'periodLabel': label,
      'flagged': flagged,
    };

    if (segments.isNotEmpty && segments.last['periodLabel'] == label) {
      segments[segments.length - 1] = today;
    } else {
      segments.add(today);
    }

    // Oldest first, so trimming takes from the front.
    final overflow = segments.length - AppConstants.seamWindowDays;
    return overflow > 0 ? segments.sublist(overflow) : segments;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _dayLabel(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  /// Writes this run's signals and clears the project's previous ones.
  ///
  /// Signals are a statement about now. One that no longer holds has to go, or
  /// the dashboard accumulates warnings nobody can clear and the whole thing
  /// becomes noise to be ignored — which is the failure mode the research
  /// describes in the tools this replaces.
  Future<void> _replaceSignalsFor({
    required String projectId,
    required List<Signal> signals,
  }) async {
    final existing = await firestore.list('$_org/signals');
    final current = {for (final signal in signals) signal.id};

    for (final entry in existing.entries) {
      if (entry.value['projectId'] != projectId) continue;
      if (current.contains(entry.key)) continue;
      await firestore.delete('$_org/signals/${entry.key}');
    }

    for (final signal in signals) {
      await firestore.write('$_org/signals/${signal.id}', {
        'title': signal.title,
        'because': signal.because,
        'severity': signal.severity.name,
        'projectId': signal.projectId,
        'raisedAt': signal.raisedAt,
      });
    }
  }

  /// Keeps the last few windows for a squad, so the next run has a baseline.
  ///
  /// Capped at one more window than the assembler reads, so the document
  /// cannot grow without limit on a project that runs for a year.
  Future<void> _appendHistory(SquadActivity activity) async {
    final existing = await _readHistory(activity.squadId);

    final windows = <Map<String, dynamic>>[
      {
        'windowStart': activity.windowStart,
        'windowEnd': activity.windowEnd,
        'commitCount': activity.commitCount,
        'tasksCompleted': activity.tasksCompleted,
        'tasksOpened': activity.tasksOpened,
        'closedIssueWeight': activity.closedIssueWeight,
        'openIssueWeight': activity.openIssueWeight,
        'contributorCount': activity.contributorCount,
        'activePersonHours': activity.activePersonHours,
      },
      for (final window in existing.take(MetricsAssembler.retainedWindows - 1))
        {
          'windowStart': window.windowStart,
          'windowEnd': window.windowEnd,
          'commitCount': window.commitCount,
          'tasksCompleted': window.tasksCompleted,
          'tasksOpened': window.tasksOpened,
          'closedIssueWeight': window.closedIssueWeight,
          'openIssueWeight': window.openIssueWeight,
          'contributorCount': window.contributorCount,
          'activePersonHours': window.activePersonHours,
        },
    ];

    await firestore.write(
      '$_org/$activityHistoryCollection/${activity.squadId}',
      {'windows': windows},
      mergeFields: const ['windows'],
    );
  }
}
