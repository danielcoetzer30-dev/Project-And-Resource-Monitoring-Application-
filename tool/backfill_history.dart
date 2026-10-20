// Gives a newly connected source the history it has but has not been asked
// about.
//
// Usage:
//   dart run tool/backfill_history.dart <path-to-key.json> [windows] [--apply]
//
// Inspects by default and changes nothing. Pass --apply to write.
//
// Velocity and commit volume compare a window against the one before it, so a
// source connected today abstains with "not enough history yet" until a
// fortnight of daily runs has accumulated. The past fortnights already
// happened and the source can still be asked about them, so this reads them
// and stores them as history.
//
// It is not invented data: the same adapters, the same anonymiser and the
// same contributor threshold, over windows that have closed. Scores are not
// backdated — a score is a statement about a project now, and the seam should
// show when the app started watching rather than imply it was always there.

// ignore_for_file: avoid_print
// A command-line tool. Printing is how it reports.

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
  if (arguments.isEmpty) {
    print(
      'Usage: dart run tool/backfill_history.dart '
      '<path-to-key.json> [windows] [--apply]',
    );
    exit(64);
  }

  final apply = arguments.contains('--apply');
  final windows = int.tryParse(arguments.length > 1 ? arguments[1] : '') ?? 3;

  final orgId = Platform.environment['KEEL_ORG_ID'] ?? 'demo-org';
  final tokens = _jsonMap('KEEL_SOURCE_TOKENS');

  final firestore = await FirestoreRest.connect(
    keyJson: await File(arguments.first).readAsString(),
    projectId: _projectId,
  );

  final runner = IngestionRunner(
    firestore: apply ? firestore : _ReadOnly(firestore),
    orgId: orgId,
    engine: HealthScoreEngine.standard(),
    service: IngestionService(
      adapters: [GitMetadataAdapter(), IssueTrackerAdapter()],
      anonymiser: const Anonymiser(),
    ),
  );

  try {
    print(apply ? 'APPLYING' : 'INSPECTING (pass --apply to write)');
    print('Reading $windows closed window(s) before now.');
    print('');

    final lines = await runner.backfillHistory(
      tokensBySourceId: tokens,
      now: DateTime.now().toUtc(),
      windows: windows,
    );

    if (lines.isEmpty) {
      print(
        'Nothing to store. Either no source reported activity in those '
        'windows, or every squad was below the contributor threshold.',
      );
    }

    lines.forEach(print);

    print('');
    print(
      apply
          ? 'Stored. The next run has a baseline to compare against.'
          : 'Nothing written.',
    );
  } finally {
    firestore.close();
  }
}

Map<String, String> _jsonMap(String name) {
  final raw = Platform.environment[name];
  if (raw == null || raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries) entry.key: entry.value.toString(),
    };
  } catch (_) {
    return const {};
  }
}

/// Reads everything, writes nothing, says what it would have written.
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
    print('  would write $path');
  }

  @override
  Future<void> delete(String path) async => print('  would delete $path');
}
