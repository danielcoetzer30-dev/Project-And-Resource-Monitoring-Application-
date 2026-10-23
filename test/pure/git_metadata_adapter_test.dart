import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:prahm/models/activity_event.dart';
import 'package:prahm/models/ingestion_source.dart';
import 'package:prahm/services/ingestion/git_metadata_adapter.dart';

/// A Git source has to fill task velocity and issue complexity, or 45% of the
/// weight abstains and the score rests on budget and commit count alone.
///
/// Pull requests are what fills them: a merged one is work finished, an opened
/// one is work arriving, and the ratio between them is what the complexity
/// calculator reads. Issues deliberately do not count, a public repository's
/// tracker holds years of user reports, and weighing that against a
/// fortnight's throughput says more about open-source culture than about a
/// team.
void main() {
  final since = DateTime.utc(2026, 10, 6);

  const source = IngestionSource(
    id: 'src1',
    type: SourceType.github,
    label: 'Riverpod',
    remoteId: 'rrousselGit/riverpod',
    orgId: 'demo-org',
    isEnabled: true,
    squadId: 's1',
  );

  /// Answers the commits and pulls endpoints from fixtures, and records which
  /// paths were asked for.
  ({http.Client client, List<String> paths}) stub({
    List<Map<String, dynamic>> commits = const [],
    List<Map<String, dynamic>> pulls = const [],
  }) {
    final paths = <String>[];

    final client = MockClient((request) async {
      paths.add(request.url.path);
      final body = request.url.path.endsWith('/commits') ? commits : pulls;
      return http.Response(jsonEncode(body), 200);
    });

    return (client: client, paths: paths);
  }

  Map<String, dynamic> commit(String email, DateTime at) => {
    'commit': {
      'author': {'email': email, 'date': at.toIso8601String()},
    },
  };

  Map<String, dynamic> pull({
    required String login,
    DateTime? createdAt,
    DateTime? mergedAt,
  }) => {
    'user': {'login': login},
    'created_at': createdAt?.toIso8601String(),
    'merged_at': mergedAt?.toIso8601String(),
  };

  test('reads commits and pull requests, and nothing else', () async {
    final s = stub(
      commits: [commit('a@example.com', DateTime.utc(2026, 10, 10))],
      pulls: [
        pull(
          login: 'Naledi',
          createdAt: DateTime.utc(2026, 10, 8),
          mergedAt: DateTime.utc(2026, 10, 12),
        ),
      ],
    );

    final events = await GitMetadataAdapter(
      client: s.client,
    ).fetchEvents(source: source, since: since, token: '');

    expect(s.paths, [
      '/repos/rrousselGit/riverpod/commits',
      '/repos/rrousselGit/riverpod/pulls',
    ], reason: 'the issues endpoint is deliberately not read');

    expect(events.map((e) => e.type).toList(), [
      ActivityType.commit,
      ActivityType.taskCompleted,
      ActivityType.taskOpened,
    ]);
  });

  test(
    'a pull request opened and merged in the window counts as both',
    () async {
      // Work arrived and work finished. Counting only the merge would hide the
      // arrival, and the complexity ratio is built from exactly that comparison.
      final s = stub(
        pulls: [
          pull(
            login: 'thabo',
            createdAt: DateTime.utc(2026, 10, 9),
            mergedAt: DateTime.utc(2026, 10, 11),
          ),
        ],
      );

      final events = await GitMetadataAdapter(
        client: s.client,
      ).fetchEvents(source: source, since: since, token: '');

      expect(events, hasLength(2));
      expect(events.map((e) => e.type).toSet(), {
        ActivityType.taskCompleted,
        ActivityType.taskOpened,
      });
    },
  );

  test(
    'a pull request opened before the window is not counted as arriving',
    () async {
      // Opened in September, merged this fortnight. The merge belongs to this
      // window; the arrival does not, and counting it would make an old queue
      // look like a sudden flood of new work.
      final s = stub(
        pulls: [
          pull(
            login: 'thabo',
            createdAt: DateTime.utc(2026, 9, 1),
            mergedAt: DateTime.utc(2026, 10, 11),
          ),
        ],
      );

      final events = await GitMetadataAdapter(
        client: s.client,
      ).fetchEvents(source: source, since: since, token: '');

      expect(events, hasLength(1));
      expect(events.single.type, ActivityType.taskCompleted);
    },
  );

  test(
    'an unmerged pull request is work arriving, not work finished',
    () async {
      final s = stub(
        pulls: [pull(login: 'naledi', createdAt: DateTime.utc(2026, 10, 10))],
      );

      final events = await GitMetadataAdapter(
        client: s.client,
      ).fetchEvents(source: source, since: since, token: '');

      expect(events.single.type, ActivityType.taskOpened);
    },
  );

  test('a closed-without-merging pull request finished nothing', () async {
    // merged_at is null when a pull request was closed rather than merged.
    // Counting it as delivery would reward abandoning work.
    final s = stub(
      pulls: [pull(login: 'naledi', createdAt: DateTime.utc(2026, 9, 1))],
    );

    final events = await GitMetadataAdapter(
      client: s.client,
    ).fetchEvents(source: source, since: since, token: '');

    expect(events, isEmpty);
  });

  test('every pull-request event carries an author to attribute it', () async {
    final s = stub(
      pulls: [
        {'created_at': DateTime.utc(2026, 10, 10).toIso8601String()},
        pull(login: 'thabo', createdAt: DateTime.utc(2026, 10, 10)),
      ],
    );

    final events = await GitMetadataAdapter(
      client: s.client,
    ).fetchEvents(source: source, since: since, token: '');

    // The one with no user is dropped rather than attributed to nobody.
    expect(events, hasLength(1));
    expect(events.single.authorKey, 'thabo');
  });
}
