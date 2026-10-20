// Points the demonstration organisation at a real repository.
//
// Usage:
//   dart run tool/configure_demo_source.dart <path-to-key.json> [--apply]
//
// Inspects by default and changes nothing. Pass --apply to write.
//
// The seeded sources point at a repository that was invented for the demo
// (northbridge/ledger) and a ClickUp board that does not exist, so every run
// reports them as unreadable. This replaces them with a public repository
// chosen because its shape resembles the teams this app is for: around eight
// contributors and a few commits a day, rather than a corporate monorepo.
//
// Only public commit metadata is read — authors, timestamps, nothing else.
// Nothing identifying is stored: the anonymiser aggregates to the squad named
// here before anything reaches Firestore, and squads below the contributor
// threshold are dropped entirely.

// ignore_for_file: avoid_print
// A command-line tool. Printing is how it reports.

import 'dart:io';

import 'package:keel/services/ingestion/firestore_rest.dart';

const _projectId = 'project-health-monitor-436da';
const _org = 'organisations/demo-org';

/// The demonstration source. See the note above on why this repository.
const _source = {
  'id': 'src1',
  'type': 'github',
  'label': 'Riverpod (demonstration data)',
  'remoteId': 'rrousselGit/riverpod',
  'isEnabled': true,
  'squadId': 's1',
};

/// The ClickUp board in the seed does not exist, so it fails every run. Left
/// in place but switched off, rather than deleted: a disabled source is a
/// record of a decision, and ingestion skips it.
const _disable = 'src2';

/// Figures ingestion cannot measure, and the one that has to be calibrated.
///
/// `weeklyHours` is what the squad is expected to put in, and idle time is
/// measured against it. Set it wrong and that indicator is meaningless: the
/// first run here used 36 hours a week against a repository whose
/// contributors logged five person-hours a fortnight, and reported 7%
/// utilisation — a number about the roster, not about the team.
///
/// Nine hours a week is what this source actually looks like: an open-source
/// project people work on around other things, not an agency billing a
/// client, and a demonstration that pretends otherwise demonstrates the wrong
/// thing.
///
/// It has been recalibrated once. Five hours was right when a Git source gave
/// commits alone and the squad logged six person-hours a fortnight. Reading
/// pull requests as well took that to eleven, which against a ten-hour roster
/// pegged utilisation at 100% — a fact about the roster again, in the
/// opposite direction. The figure has to follow what the source actually
/// reports.
///
/// For a real team this comes from what they committed to, not from what
/// makes the number look good. Spending more of a budget always lowers the
/// score, so none of this can be tuned to flatter.
const _plan = {
  'budgetTotal': 180000.0,
  'budgetSpent': 94000.0,
  'weeklyHours': 9.0,
};

/// What the squad has in a week, across everything it works on.
///
/// Stated by the team, the same way a headcount is, and for the same reason
/// it cannot be measured: a commit log knows that somebody worked, not how
/// many hours they had. Capacity is the committed hours over this.
///
/// It used to be a headcount times a forty-hour week, which assumed everybody
/// is full-time on this work and made a part-time squad read as permanently
/// idle. Twenty hours is what this one looks like: a handful of people on an
/// open-source project around other commitments.
const _squadWeeklyHours = 20.0;

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print(
      'Usage: dart run tool/configure_demo_source.dart '
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
    print('');

    final sources = await store.list('$_org/sources');
    print('Sources now:');
    for (final entry in sources.entries) {
      print(
        '  ${entry.key}: ${entry.value['remoteId']} '
        'enabled=${entry.value['isEnabled']} '
        'squad=${entry.value['squadId'] ?? '(none)'}',
      );
    }

    final projects = await store.list('$_org/projects');
    final onSquad = projects.entries
        .where((e) => e.value['squadId'] == _source['squadId'])
        .toList();

    print('');
    print('Projects on squad ${_source['squadId']}:');
    for (final entry in onSquad) {
      print('  ${entry.key}: ${entry.value['name']}');
    }

    if (onSquad.isEmpty) {
      print('  none — nothing would be scored. Stopping.');
      exit(1);
    }

    print('');
    print('Would set sources/${_source['id']} -> ${_source['remoteId']}');
    print('Would disable sources/$_disable');
    for (final entry in onSquad) {
      print('Would set projectPlans/${entry.key} -> $_plan');
    }
    print(
      'Would set squads/${_source['squadId']} '
      'weeklyHours -> $_squadWeeklyHours',
    );

    if (!apply) return;

    print('');
    await store.write('$_org/sources/${_source['id']}', {
      'type': _source['type'],
      'label': _source['label'],
      'remoteId': _source['remoteId'],
      'isEnabled': _source['isEnabled'],
      'squadId': _source['squadId'],
    });
    print('Set sources/${_source['id']}');

    if (sources.containsKey(_disable)) {
      await store.write(
        '$_org/sources/$_disable',
        {'isEnabled': false},
        mergeFields: const ['isEnabled'],
      );
      print('Disabled sources/$_disable');
    }

    // Dates are set relative to now so the demonstration always has a
    // project that is partly through its schedule, whenever it is run.
    final now = DateTime.now().toUtc();

    for (final entry in onSquad) {
      await store.write('$_org/projectPlans/${entry.key}', {
        ..._plan,
        'startDate': now.subtract(const Duration(days: 54)),
        'endDate': now.add(const Duration(days: 36)),
      });
      print('Set projectPlans/${entry.key}');
    }

    // Merged, so the name and headcount the team stated are left alone.
    await store.write(
      '$_org/squads/${_source['squadId']}',
      {'weeklyHours': _squadWeeklyHours},
      mergeFields: const ['weeklyHours'],
    );
    print('Set squads/${_source['squadId']} weeklyHours');

    print('');
    print('Done. Run tool/ingest.dart --dry-run to see what it would score.');
  } finally {
    store.close();
  }
}
