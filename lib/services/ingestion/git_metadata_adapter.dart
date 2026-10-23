import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/exceptions.dart';
import '../../models/activity_event.dart';
import '../../models/ingestion_source.dart';
import 'ingestion_adapter.dart';

/// Reads commit and pull-request metadata from GitHub.
///
/// Two endpoints, nothing else. Commit messages, diffs and pull-request
/// bodies are never requested: an author, a timestamp and the fact that the
/// thing happened is all the scoring engine needs.
///
/// Pull requests count as tasks. A merged one is work finished, an opened one
/// is work arriving, and the ratio between them is what the complexity
/// calculator reads. Without them, task velocity and issue complexity (45% of
/// the weight) have nothing to measure.
///
/// Issues are deliberately not read: a public tracker holds years of reports,
/// so weighing that stock against a fortnight's throughput says more about
/// open-source culture than about a team.
class GitMetadataAdapter implements IngestionAdapter {
  GitMetadataAdapter({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _apiRoot = 'https://api.github.com';

  /// GitHub caps a page at 100, and this does not page further.
  ///
  /// A fortnight of activity fits comfortably for the teams this is built for
  ///, the sampled repositories run 5 to 20 pull requests a fortnight. A
  /// repository busy enough to exceed this would be silently under-reported,
  /// which is the one failure mode here worth knowing about.
  static const _perPage = 100;

  @override
  SourceType get type => SourceType.github;

  @override
  Future<List<RawActivityEvent>> fetchEvents({
    required IngestionSource source,
    required DateTime since,
    required String token,
  }) async {
    return [
      ...await _commits(source: source, since: since, token: token),
      ...await _pullRequests(source: source, since: since, token: token),
    ];
  }

  Future<List<RawActivityEvent>> _commits({
    required IngestionSource source,
    required DateTime since,
    required String token,
  }) async {
    final decoded = await _getList(
      source: source,
      token: token,
      path:
          '/repos/${source.remoteId}/commits'
          '?since=${since.toUtc().toIso8601String()}&per_page=$_perPage',
    );

    final events = <RawActivityEvent>[];

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;

      final commit = item['commit'] as Map<String, dynamic>?;
      final author = commit?['author'] as Map<String, dynamic>?;

      final email = author?['email'] as String?;
      final dateText = author?['date'] as String?;
      if (email == null || dateText == null) continue;

      final occurredAt = DateTime.tryParse(dateText);
      if (occurredAt == null) continue;

      events.add(
        RawActivityEvent(
          sourceId: source.id,
          authorKey: email.toLowerCase(),
          occurredAt: occurredAt,
          type: ActivityType.commit,
        ),
      );
    }

    return events;
  }

  /// Pull requests opened or merged since [since].
  ///
  /// Sorted by most recently updated, which is the only ordering GitHub
  /// offers that reliably surfaces a window's activity in one page. Anything
  /// outside the window is dropped here; the anonymiser would drop it again,
  /// but filtering early keeps the event list honest about what it contains.
  Future<List<RawActivityEvent>> _pullRequests({
    required IngestionSource source,
    required DateTime since,
    required String token,
  }) async {
    final decoded = await _getList(
      source: source,
      token: token,
      path:
          '/repos/${source.remoteId}/pulls'
          '?state=all&sort=updated&direction=desc&per_page=$_perPage',
    );

    final events = <RawActivityEvent>[];

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;

      // The login, not the email: GitHub does not give an email on a pull
      // request, and it does not need to. This is used once to decide which
      // squad the event belongs to and discarded by the anonymiser.
      final user = item['user'] as Map<String, dynamic>?;
      final login = user?['login'] as String?;
      if (login == null) continue;

      final authorKey = login.toLowerCase();

      final mergedAt = _parse(item['merged_at']);
      if (mergedAt != null && !mergedAt.isBefore(since)) {
        events.add(
          RawActivityEvent(
            sourceId: source.id,
            authorKey: authorKey,
            occurredAt: mergedAt,
            type: ActivityType.taskCompleted,
          ),
        );
      }

      final createdAt = _parse(item['created_at']);
      if (createdAt != null && !createdAt.isBefore(since)) {
        events.add(
          RawActivityEvent(
            sourceId: source.id,
            authorKey: authorKey,
            occurredAt: createdAt,
            type: ActivityType.taskOpened,
          ),
        );
      }
    }

    return events;
  }

  /// A pull request opened and merged inside the same window counts as both,
  /// which is correct: work arrived and work finished.
  static DateTime? _parse(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  /// Fetches a list endpoint, turning every failure into a typed exception
  /// naming the source, so a broken one is identifiable in a job log.
  Future<List<dynamic>> _getList({
    required IngestionSource source,
    required String token,
    required String path,
  }) async {
    final http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$_apiRoot$path'),
        headers: {
          'Accept': 'application/vnd.github+json',
          // Omitted when there is no token. A public repository's metadata is
          // readable without one, which is how this can be demonstrated
          // against a real repository with no credential anywhere. A private
          // repository without a token gets a 404 from GitHub, reported below
          // as a source that could not be read.
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
    } catch (error) {
      throw NetworkException('Could not reach GitHub: $error');
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw const PermissionException(
          'GitHub refused the request. Check the access token for this source.',
        );
      case 404:
        throw PermissionException(
          'Repository ${source.remoteId} not found, or the token cannot see it.',
        );
      default:
        throw NetworkException(
          'GitHub returned ${response.statusCode} for ${source.remoteId}.',
        );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const ParseException('GitHub returned an unexpected shape.');
    }

    return decoded;
  }

  void dispose() => _client.close();
}
