import '../../core/constants/app_constants.dart';
import '../../core/errors/failure.dart';
import '../../models/health_state.dart';
import '../../models/ingestion_source.dart';
import '../../models/outage_window.dart';
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
      final history = await _readHistory(squadId);

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
        plan: plan,
        activity: activity,
        openSignals: signals.length,
        now: now,
      );

      await _replaceSignalsFor(projectId: projectId, signals: signals);

      scored++;
      raised += signals.length;
    }

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
          ),
    ];
  }

  // --- Writes ---------------------------------------------------------------

  Future<void> _writeProject({
    required String projectId,
    required Map<String, dynamic> existing,
    required HealthAssessment assessment,
    required ProjectPlan plan,
    required SquadActivity activity,
    required int openSignals,
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
      'updatedAt': now,
    };

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
      },
      for (final window in existing.take(MetricsAssembler.historyWindows))
        {
          'windowStart': window.windowStart,
          'windowEnd': window.windowEnd,
          'commitCount': window.commitCount,
          'tasksCompleted': window.tasksCompleted,
          'tasksOpened': window.tasksOpened,
          'closedIssueWeight': window.closedIssueWeight,
          'openIssueWeight': window.openIssueWeight,
          'contributorCount': window.contributorCount,
        },
    ];

    await firestore.write(
      '$_org/$activityHistoryCollection/${activity.squadId}',
      {'windows': windows},
      mergeFields: const ['windows'],
    );
  }
}
