import '../../core/errors/failure.dart';
import '../../models/activity_event.dart';
import '../../models/ingestion_source.dart';
import '../../models/squad_activity.dart';
import 'anonymiser.dart';
import 'ingestion_adapter.dart';

/// What one ingestion run produced.
class IngestionResult {
  const IngestionResult({
    required this.activity,
    required this.suppressedSquads,
    required this.failures,
    required this.ranAt,
  });

  final List<SquadActivity> activity;

  /// Squads that had activity but too few contributors to report anonymously.
  final List<String> suppressedSquads;

  /// Sources that could not be read, by source id. A run continues when one
  /// source fails — a broken ClickUp token should not stop GitHub ingestion.
  final Map<String, Failure> failures;

  final DateTime ranAt;

  bool get isCompletelyFailed => activity.isEmpty && failures.isNotEmpty;
}

/// Orchestrates passive capture.
///
/// The ordering here is the important part: every adapter's raw output goes
/// straight into the anonymiser, and only the anonymiser's output is returned.
/// Raw events never leave this method, are never cached, and are never written
/// anywhere.
class IngestionService {
  const IngestionService({required this.adapters, required this.anonymiser});

  final List<IngestionAdapter> adapters;
  final Anonymiser anonymiser;

  Future<IngestionResult> run({
    required List<IngestionSource> sources,
    required Map<String, String> tokensBySourceId,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) async {
    final rawEvents = <RawActivityEvent>[];
    final failures = <String, Failure>{};

    for (final source in sources) {
      if (!source.isEnabled) continue;

      final adapter = _adapterFor(source.type);
      if (adapter == null) {
        failures[source.id] = DataFailure(
          'No adapter for ${source.type.label}.',
        );
        continue;
      }

      final token = tokensBySourceId[source.id];
      if (token == null || token.isEmpty) {
        failures[source.id] = AuthFailure(
          'No access token configured for ${source.label}.',
        );
        continue;
      }

      try {
        final events = await adapter.fetchEvents(
          source: source,
          since: windowStart,
          token: token,
        );
        rawEvents.addAll(events);
      } catch (error) {
        // One bad source does not fail the run.
        failures[source.id] = failureFromException(error);
      }
    }

    final activity = anonymiser.anonymise(
      events: rawEvents,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );

    final suppressed = anonymiser.suppressedSquads(
      events: rawEvents,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );

    // rawEvents goes out of scope here and is never referenced again. Nothing
    // below this line has access to an author key.
    return IngestionResult(
      activity: activity,
      suppressedSquads: suppressed,
      failures: failures,
      ranAt: DateTime.now(),
    );
  }

  IngestionAdapter? _adapterFor(SourceType type) {
    for (final adapter in adapters) {
      if (adapter.type == type) return adapter;
    }
    return null;
  }
}
