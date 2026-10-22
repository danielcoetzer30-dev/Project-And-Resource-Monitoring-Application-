// Removes the seeded demonstration projects that no source feeds.
//
// Usage:
//   dart run tool/remove_seed_projects.dart <path-to-key.json> [--apply]
//
// Inspects by default and changes nothing. Pass --apply to write.
//
// The original seed invented four projects. Two of them — p2 "Fleet tracker
// v2" on squad s2 and p4 "POS integration" on squad s3 — belong to squads
// with no working source, so ingestion has skipped them since September and
// their figures have been frozen at whatever the seed set. A dashboard
// showing a live score beside a four-week-old one teaches somebody to
// distrust both, which is the opposite of what this tool is for.
//
// p1 and p3 are deliberately kept: they are on squad s1, which the riverpod
// source feeds, so their scores are real and current.
//
// Signals are deleted with them. Both existing signals point at p2, and a
// signal whose project has gone renders with no name against it — worse than
// not being there, because it looks like a bug rather than an absence.
//
// Everything removed is written to a backup file first. These are seeded
// records rather than anything a team produced, but "it was only demo data"
// is what everybody says after deleting the wrong thing.

// ignore_for_file: avoid_print
// A command-line tool. Printing is how it reports.

import 'dart:convert';
import 'dart:io';

import 'package:prahm/services/ingestion/firestore_rest.dart';

const _projectId = 'project-health-monitor-436da';
const _org = 'organisations/demo-org';

/// Seeded projects on squads that no source feeds.
const _projects = ['p2', 'p4'];

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print(
      'Usage: dart run tool/remove_seed_projects.dart '
      '<path-to-key.json> [--apply]',
    );
    exit(64);
  }

  final apply = arguments.contains('--apply');
  final store = await FirestoreRest.connect(
    keyJson: await File(arguments.first).readAsString(),
    projectId: _projectId,
  );

  try {
    print(apply ? 'APPLYING' : 'INSPECTING (pass --apply to write)');

    final backup = <String, Map<String, dynamic>>{};

    // Projects.
    final projects = await store.list('$_org/projects');
    final removing = <String>[];

    print('');
    print('Projects:');
    for (final entry in projects.entries) {
      final doomed = _projects.contains(entry.key);
      print(
        '  ${entry.key}: ${entry.value['name']} '
        '(squad ${entry.value['squadId']}) '
        '${doomed ? '-> REMOVE' : '-> keep'}',
      );
      if (doomed) {
        removing.add('$_org/projects/${entry.key}');
        backup['projects/${entry.key}'] = entry.value;
      }
    }

    // Signals belonging to a project that is going.
    final signals = await store.list('$_org/signals');

    print('');
    print('Signals:');
    for (final entry in signals.entries) {
      final target = entry.value['projectId'] as String?;
      final orphaned = target != null && _projects.contains(target);
      print(
        '  ${entry.key}: on $target '
        '${orphaned ? '-> REMOVE (its project is going)' : '-> keep'}',
      );
      if (orphaned) {
        removing.add('$_org/signals/${entry.key}');
        backup['signals/${entry.key}'] = entry.value;
      }
    }

    // Plans, in case one was ever written for these. There are none today,
    // but a plan left behind would have ingestion recreate the project on the
    // next run, which would look like the deletion silently failing.
    final plans = await store.list('$_org/projectPlans');

    print('');
    print('Plans:');
    var anyPlan = false;
    for (final entry in plans.entries) {
      if (!_projects.contains(entry.key)) continue;
      anyPlan = true;
      print('  ${entry.key}: ${entry.value['name']} -> REMOVE');
      removing.add('$_org/projectPlans/${entry.key}');
      backup['projectPlans/${entry.key}'] = entry.value;
    }
    if (!anyPlan) {
      print('  none for these projects, so ingestion will not recreate them');
    }

    print('');
    print('${removing.length} document(s) would be removed.');

    if (!apply) return;

    final file = File(
      'seed-removal-backup-'
      '${DateTime.now().toIso8601String().replaceAll(':', '-')}.json',
    );
    // Timestamps come back as DateTime, which JSON cannot encode. Written as
    // ISO-8601 rather than dropped: a backup missing the dates would not be
    // enough to put a document back.
    await file.writeAsString(
      JsonEncoder.withIndent(
        '  ',
        (value) => value is DateTime ? value.toIso8601String() : '$value',
      ).convert(backup),
    );
    print('');
    print('Backed up to ${file.path}');

    for (final path in removing) {
      await store.delete(path);
      print('Deleted $path');
    }

    print('');
    print(
      'Done. The Signals tab will now be empty until a real score falls '
      'far enough to raise one.',
    );
  } finally {
    store.close();
  }
}
