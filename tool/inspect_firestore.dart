// Prints what is actually in the demonstration organisation.
//
// Usage:
//   dart run tool/inspect_firestore.dart <path-to-key.json> [collection]
//
// Reads only. Written because "the schema is not implemented" and "I cannot
// find it in the console" are different problems with the same symptom, and
// the console groups subcollections in a way that makes an empty one and a
// missing one look identical.

// ignore_for_file: avoid_print
// A command-line tool. Printing is how it reports.

import 'dart:io';

import 'package:prahm/services/ingestion/firestore_rest.dart';

const _projectId = 'project-health-monitor-436da';
const _org = 'organisations/demo-org';

/// Every collection docs/SCHEMA.md says should exist, in the order that file
/// lists them, so a gap is obvious.
const _expected = [
  'projects',
  'squads',
  'signals',
  'outages',
  'sources',
  'projectPlans',
  'settings',
  'directory',
  'squadMembers',
  'conversations',
];

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print(
      'Usage: dart run tool/inspect_firestore.dart <key.json> [collection]',
    );
    exit(64);
  }

  final store = await FirestoreRest.connect(
    keyJson: await File(arguments.first).readAsString(),
    projectId: _projectId,
  );

  final only = arguments.length > 1 ? arguments[1] : null;

  try {
    for (final name in _expected) {
      if (only != null && only != name) continue;

      final docs = await store.list('$_org/$name');

      print('');
      print('=== $name  (${docs.length} documents) ===');

      if (docs.isEmpty) {
        print('  (empty)');
        continue;
      }

      for (final entry in docs.entries) {
        final fields = entry.value.keys.toList()..sort();
        print('  ${entry.key}');
        print('    fields: ${fields.join(', ')}');

        // The few values worth seeing at a glance when working out why a
        // dashboard looks wrong.
        for (final key in const [
          'name',
          'score',
          'state',
          'squadId',
          'isArchived',
          'isEnabled',
          'remoteId',
          'lastSyncedAt',
          'updatedAt',
          'displayName',
          'role',
          'projectId',
          'title',
          'severity',
          'headcount',
          'weeklyHours',
        ]) {
          if (entry.value.containsKey(key)) {
            print('    $key: ${entry.value[key]}');
          }
        }
      }
    }
  } finally {
    store.close();
  }
}
