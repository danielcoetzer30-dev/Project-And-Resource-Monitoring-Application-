// The scheduled ingestion run.
//
// Usage (normally from .github/workflows/ingest.yml):
//   dart run tool/ingest.dart
//
// Everything comes from the environment, because everything here is either a
// credential or a mapping that must not be committed:
//
//   FIREBASE_SERVICE_ACCOUNT  the whole service-account JSON key
//   KEEL_SQUAD_OF_AUTHOR      {"github-username": "squadId", ...}
//   KEEL_SOURCE_TOKENS        {"sourceId": "token", ...}
//   KEEL_ORG_ID               defaults to demo-org
//   KEEL_WINDOW_HOURS         defaults to 6, and should match the cron
//
// KEEL_SQUAD_OF_AUTHOR is the one genuinely identifying piece of
// configuration in this system. It maps a person to a squad, which is exactly
// the link the rest of the design exists to sever. It lives in a secret, is
// held in memory for the length of one run, and is never written anywhere —
// see the doc comment on Anonymiser.squadOfAuthor.
//
// --dry-run reads and scores but writes nothing, which is how to try this
// against real data without touching it.

// ignore_for_file: avoid_print
// A command-line job. Printing is how it reports to the Actions log.

import 'dart:convert';
import 'dart:io';

import 'package:keel/services/health_scoring/health_score_engine.dart';
import 'package:keel/services/ingestion/anonymiser.dart';
import 'package:keel/services/ingestion/firestore_rest.dart';
import 'package:keel/services/ingestion/git_metadata_adapter.dart';
import 'package:keel/services/ingestion/ingestion_runner.dart';
import 'package:keel/services/ingestion/ingestion_service.dart';
import 'package:keel/services/ingestion/issue_tracker_adapter.dart';

const _projectId = 'project-health-monitor-436da';

Future<void> main(List<String> arguments) async {
  final dryRun = arguments.contains('--dry-run');

  final keyJson = _required('FIREBASE_SERVICE_ACCOUNT');
  final squadOfAuthor = _jsonMap('KEEL_SQUAD_OF_AUTHOR');
  final tokens = _jsonMap('KEEL_SOURCE_TOKENS');

  final orgId = Platform.environment['KEEL_ORG_ID'] ?? 'demo-org';
  final windowHours =
      int.tryParse(Platform.environment['KEEL_WINDOW_HOURS'] ?? '') ?? 6;

  if (squadOfAuthor.isEmpty) {
    // Not an error worth failing on, but worth saying loudly: with no
    // mapping, every event is discarded and the run quietly does nothing.
    print(
      'WARNING: KEEL_SQUAD_OF_AUTHOR is empty, so no event can be attributed '
      'to a squad and nothing will be scored.',
    );
  }

  final firestore = await FirestoreRest.connect(
    keyJson: keyJson,
    projectId: _projectId,
  );

  final runner = IngestionRunner(
    firestore: dryRun ? _ReadOnly(firestore) : firestore,
    orgId: orgId,
    engine: HealthScoreEngine.standard(),
    service: IngestionService(
      adapters: [GitMetadataAdapter(), IssueTrackerAdapter()],
      anonymiser: Anonymiser(squadOfAuthor: squadOfAuthor),
    ),
  );

  try {
    final report = await runner.run(
      tokensBySourceId: tokens,
      now: DateTime.now().toUtc(),
      window: Duration(hours: windowHours),
    );

    if (dryRun) print('DRY RUN — nothing was written.');
    report.summary.forEach(print);

    // A run where every source failed is a failure, so the Action goes red
    // and somebody looks. A run where one source failed is not: a broken
    // ClickUp token should not stop GitHub ingestion, and the log says so.
    if (report.projectsScored == 0 && report.failures.isNotEmpty) {
      print('');
      print('Every source failed. Failing the job so this is noticed.');
      exit(1);
    }
  } finally {
    firestore.close();
  }
}

String _required(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    print('Missing $name. In Actions this comes from a repository secret.');
    exit(78);
  }
  return value;
}

/// Reads a JSON object of string to string from the environment.
///
/// An absent variable is an empty map rather than a failure: a team with no
/// ClickUp board should not have to invent a token to run GitHub ingestion.
Map<String, String> _jsonMap(String name) {
  final raw = Platform.environment[name];
  if (raw == null || raw.trim().isEmpty) return const {};

  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries) entry.key: entry.value.toString(),
    };
  } catch (_) {
    print('$name is not a JSON object. Expected {"key": "value"}.');
    exit(78);
  }
}

/// Wraps the store so a dry run can read everything and write nothing.
///
/// Belt and braces: the point of --dry-run is to try this against real data,
/// and "I thought it was a dry run" is not a recoverable mistake on a
/// database nobody has a backup of.
class _ReadOnly implements FirestoreStore {
  const _ReadOnly(this._inner);

  final FirestoreStore _inner;

  @override
  Future<Map<String, dynamic>?> get(String path) => _inner.get(path);

  @override
  Future<Map<String, Map<String, dynamic>>> list(String path) =>
      _inner.list(path);

  @override
  Future<void> write(
    String path,
    Map<String, dynamic> data, {
    List<String>? mergeFields,
  }) async {
    print('  would write $path (${data.keys.join(', ')})');
  }

  @override
  Future<void> delete(String path) async {
    print('  would delete $path');
  }
}
