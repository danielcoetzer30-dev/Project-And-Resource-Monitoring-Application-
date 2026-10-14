// Proves an ingestion service-account key actually works, before it goes
// anywhere near a GitHub secret.
//
// Usage:
//   dart run tool/check_ingestion_credentials.dart <path-to-key.json> [orgId]
//
// Checks three things in order, because they fail for different reasons and
// the difference matters:
//
//   1. The key parses and Google accepts it      -> the file is intact
//   2. A collection can be read                  -> the account exists
//   3. A document can be written and deleted     -> the role is right
//
// Step 3 is the one worth having. Cloud Datastore *Viewer* passes steps 1 and
// 2 and then fails on the first write of a scheduled run, hours later, in a
// log nobody is watching.
//
// Pass the key by path. Never copy it into this repository, and never paste
// its contents into a terminal or a chat.

// ignore_for_file: avoid_print
// This is a command-line tool. Printing is how it reports, and a logging
// framework would be machinery without a job.

import 'dart:io';

import 'package:keel/core/errors/exceptions.dart';
import 'package:keel/services/ingestion/firestore_rest.dart';

const _projectId = 'project-health-monitor-436da';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print(
      'Usage: dart run tool/check_ingestion_credentials.dart '
      '<path-to-key.json> [orgId]',
    );
    exit(64);
  }

  final keyPath = arguments.first;
  final orgId = arguments.length > 1 ? arguments[1] : 'demo-org';

  final file = File(keyPath);
  if (!file.existsSync()) {
    print('No file at $keyPath');
    print(
      'Pass the path to the JSON key you downloaded, in quotes if it '
      'contains spaces.',
    );
    exit(66);
  }

  if (_isInsideRepository(file)) {
    print('REFUSING: that key is inside the repository.');
    print(
      'Move it somewhere outside this folder first. A service-account key '
      'in a repo is one `git add -A` away from being published.',
    );
    exit(1);
  }

  final keyJson = await file.readAsString();

  FirestoreRest? firestore;

  try {
    firestore = await FirestoreRest.connect(
      keyJson: keyJson,
      projectId: _projectId,
    );
    print('1/3  Key accepted by Google.');

    final projects = await firestore.list('organisations/$orgId/projects');
    print(
      '2/3  Read organisations/$orgId/projects '
      '— ${projects.length} project(s).',
    );

    // Written into ingestion's own working-state collection, which no client
    // has a rule granting access to, and removed again immediately.
    // Not wrapped in double underscores: Firestore reserves those ids.
    const probePath = 'activityHistory/credential-check';
    final fullPath = 'organisations/$orgId/$probePath';

    await firestore.write(fullPath, {'checkedAt': DateTime.now().toUtc()});
    final readBack = await firestore.get(fullPath);

    if (readBack == null || readBack['checkedAt'] == null) {
      print('3/3  Write reported success but nothing came back. Stopping.');
      exit(1);
    }

    await firestore.delete(fullPath);
    print('3/3  Wrote, read back and deleted a probe document.');

    print('');
    print('Good. This key can run ingestion.');
    print(
      'Next: add it to the repository as the secret '
      'FIREBASE_SERVICE_ACCOUNT.',
    );
  } on PermissionException catch (error) {
    print('');
    print('REFUSED: ${error.message}');
    print('');
    print(
      'Almost always the role. In the Cloud console, under '
      'IAM and admin -> IAM, the keel-ingestion account needs',
    );
    print('  Cloud Datastore User');
    print('Viewer can read but not write, which is what this looks like.');
    print('');
    print(
      'IAM changes take a few minutes to apply. If you only just set the '
      'role, wait and run this again before changing anything.',
    );
    exit(1);
  } on AuthException catch (error) {
    print('');
    print('REFUSED: ${error.message}');
    exit(1);
  } catch (error) {
    print('');
    print('Failed: $error');
    exit(1);
  } finally {
    firestore?.close();
  }
}

/// True when the key sits inside this repository, where a commit could pick
/// it up. Compared as absolute paths so `..` cannot talk its way out.
bool _isInsideRepository(File key) {
  final repoRoot = Directory.current.absolute.path.replaceAll(r'\', '/');
  final keyPath = key.absolute.path.replaceAll(r'\', '/');
  return keyPath.startsWith('$repoRoot/');
}
